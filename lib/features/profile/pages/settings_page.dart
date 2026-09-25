import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_client.dart';
import '../../../core/config/api_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/data/auth_repository.dart';

import 'package:permission_handler/permission_handler.dart';

// ── Notification preference providers ─────────────────────────────────────────

final _pushEnabledProvider = AsyncNotifierProvider<PushNotificationNotifier, bool>(PushNotificationNotifier.new);
final _emailEnabledProvider = NotifierProvider<_EmailNotifier, bool>(_EmailNotifier.new);

/// Email preference toggle — syncs to the backend JSONB `preferences` column.
/// Uses `ref.watch` so the initial value reacts to profile refreshes (e.g. after
/// login), and optimistically updates the UI, rolling back on API failure.
class _EmailNotifier extends Notifier<bool> {
  @override
  bool build() {
    // watch (not read) so the toggle updates if the user profile is refreshed.
    final user = ref.watch(currentUserProvider);
    return user?.preferences?['email_enabled'] as bool? ?? true;
  }

  Future<void> toggle() async {
    final previous = state;
    final newState = !previous;
    // Optimistic UI update
    state = newState;
    try {
      await _syncPreference('email_enabled', newState);
    } catch (_) {
      // Revert on failure — the pragmatic approach: never leave the UI lying
      // to the user about what the backend actually stored.
      state = previous;
    }
  }

  Future<void> _syncPreference(String key, bool value) async {
    final user = ref.read(currentUserProvider);
    final prefs = Map<String, dynamic>.from(user?.preferences ?? {});
    prefs[key] = value;
    final repo = ref.read(authRepositoryProvider);
    final updatedUser = await repo.updatePreferences(prefs);
    ref.read(currentUserProvider.notifier).set(updatedUser);
  }
}

/// Push notification toggle — bridges the OS-level permission with the backend
/// JSONB `preferences.push_enabled` field.
///
/// Key design decisions:
///   • Uses `WidgetsBindingObserver` to auto-detect permission changes when the
///     user returns from the OS Settings app.
///   • Backend sync errors are caught and surfaced to the user via SnackBar
///     instead of silently swallowed.
///   • Does NOT set the global `authNotifierProvider` to loading — preferences
///     are a lightweight side-channel, not a global auth event.
class PushNotificationNotifier extends AsyncNotifier<bool> with WidgetsBindingObserver {
  @override
  Future<bool> build() async {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return _checkOsStatus();
  }

  /// Called by Flutter when the app transitions between foreground/background.
  /// When the user comes back from OS Settings, we re-check the permission and
  /// sync the delta to the backend.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _checkOsStatus().then((isGranted) {
        if (state.value != isGranted) {
          state = AsyncValue.data(isGranted);
          _syncToBackend(isGranted);
        }
      }).catchError((_) {
        // Lifecycle observer must never throw — a network blip here is
        // non-fatal; the next resume will retry automatically.
      });
    }
  }

  Future<bool> _checkOsStatus() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Syncs the push_enabled flag to the backend JSONB column.
  /// Errors are intentionally propagated so callers can show user feedback.
  Future<void> _syncToBackend(bool isGranted) async {
    final user = ref.read(currentUserProvider);
    final prefs = Map<String, dynamic>.from(user?.preferences ?? {});
    prefs['push_enabled'] = isGranted;
    final repo = ref.read(authRepositoryProvider);
    final updatedUser = await repo.updatePreferences(prefs);
    ref.read(currentUserProvider.notifier).set(updatedUser);
  }

  /// The main toggle action — called from the Settings page Switch widget.
  /// Handles all three OS permission states and syncs the result to backend.
  Future<void> toggle(BuildContext context) async {
    final currentlyEnabled = state.value ?? false;

    if (!currentlyEnabled) {
      // ── Trying to turn ON ──────────────────────────────────────────
      var status = await Permission.notification.status;

      if (status.isGranted) {
        state = const AsyncValue.data(true);
        await _trySyncWithFeedback(true, context);
      } else if (status.isPermanentlyDenied) {
        if (context.mounted) _showSettingsDialog(context);
      } else {
        // First ask or soft-denied — show the native OS prompt
        status = await Permission.notification.request();
        if (status.isGranted) {
          state = const AsyncValue.data(true);
          await _trySyncWithFeedback(true, context);
        } else if (status.isPermanentlyDenied && context.mounted) {
          _showSettingsDialog(context);
        }
        // If simply denied (not permanently), we do nothing — the user can
        // try again later. No backend sync needed.
      }
    } else {
      // ── Trying to turn OFF ─────────────────────────────────────────
      state = const AsyncValue.data(false);
      await _trySyncWithFeedback(false, context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Push notifications disabled. To fully revoke, visit OS Settings.'),
          ),
        );
      }
    }
  }

  /// Wraps `_syncToBackend` with error handling + user feedback.
  Future<void> _trySyncWithFeedback(bool value, BuildContext context) async {
    try {
      await _syncToBackend(value);
    } catch (_) {
      // Revert the UI toggle so it doesn't lie to the user
      state = AsyncValue.data(!value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save preference. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notification Permission'),
        content: const Text(
          'Notification permission was permanently denied. '
          'Please enable it in app settings to receive notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pushEnabled = ref.watch(_pushEnabledProvider);
    final emailEnabled = ref.watch(_emailEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: const BackButton(),
      ),
      body: ListView(
        // Extra bottom padding so the last tiles scroll clear of the
        // floating bottom nav bar.
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        children: [
          // ── Account ──────────────────────────────────────────────────
          _SectionHeader('Account'),
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            label: 'Edit Profile',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
            onTap: () => context.push('/profile/settings/edit'),
          ),
          _SettingsTile(
            icon: Icons.workspace_premium_outlined,
            label: 'My Certificates',
            subtitle: 'Volunteer contribution certificates',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
            onTap: () => context.push('/profile/settings/certificates'),
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            label: 'PAN Management',
            subtitle: 'Securely update your PAN for 80G receipts',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
            onTap: () => _showPanSheet(context),
          ),

          // ── Notifications ─────────────────────────────────────────────
          _SectionHeader('Notifications'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Push Notifications',
            subtitle: 'Drives, badge unlocks, campaign updates',
            trailing: pushEnabled.when(
              data: (enabled) => Switch.adaptive(
                value: enabled,
                onChanged: (_) => ref.read(_pushEnabledProvider.notifier).toggle(context),
                activeTrackColor: AppColors.primaryBlue,
              ),
              loading: () => const SizedBox(width: 48, height: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => const Icon(Icons.error_outline_rounded, color: AppColors.errorRed),
            ),
          ),
          _SettingsTile(
            icon: Icons.email_outlined,
            label: 'Email Notifications',
            subtitle: 'Receipts, event reminders, newsletters',
            trailing: Switch.adaptive(
              value: emailEnabled,
              onChanged: (_) => ref.read(_emailEnabledProvider.notifier).toggle(),
              activeTrackColor: AppColors.primaryBlue,
            ),
          ),

          // ── 80G Tax Vault ────────────────────────────────────────────
          _SectionHeader('Tax & Compliance'),
          _SettingsTile(
            icon: Icons.receipt_long_rounded,
            label: '80G Tax Vault',
            subtitle: 'View donations & download tax receipts',
            iconColor: AppColors.forestGreen,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('View', style: TextStyle(color: AppColors.forestGreen, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
            onTap: () => context.push('/profile/settings/tax-vault'),
          ),

          // ── Legal ─────────────────────────────────────────────────────
          _SectionHeader('Legal'),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'Terms & Conditions',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
            onTap: () => context.push('/profile/settings/terms'),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
            onTap: () => context.push('/profile/settings/privacy'),
          ),
          _SettingsTile(
            icon: Icons.article_outlined,
            label: '80G Exemption Details',
            trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.textLight),
            onTap: () => _openUrl('https://bluedot.org/80g'),
          ),

          // ── About ─────────────────────────────────────────────────────
          _SectionHeader('About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'App Version',
            trailing: const Text('1.0.0 (Demo)', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
          ),

          // ── Danger zone ───────────────────────────────────────────────
          _SectionHeader('Danger Zone'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout_rounded, color: AppColors.errorRed),
              label: const Text('Sign Out', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                side: BorderSide(color: AppColors.errorRed.withAlpha(120)),
                shape: const StadiumBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: OutlinedButton.icon(
              onPressed: () => _confirmDeleteAccount(context, ref),
              icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorRed),
              label: const Text('Delete Account', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.errorRed.withAlpha(10),
                side: const BorderSide(color: AppColors.errorRed),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      // Root navigator so the sheet renders above the shell's floating nav bar.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _PanManagementSheet(),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.errorRed)),
        content: const Text('This will permanently delete all your data, scans, and badges. Your tax receipts and impact points will be anonymized. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleting account...'), duration: Duration(seconds: 1)),
              );

              try {
                await ref.read(authNotifierProvider.notifier).deleteAccount();
                if (context.mounted) context.go('/login');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: AppColors.errorRed),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── PAN Management Sheet ──────────────────────────────────────────────────────

class _PanManagementSheet extends ConsumerStatefulWidget {
  const _PanManagementSheet();

  @override
  ConsumerState<_PanManagementSheet> createState() => _PanManagementSheetState();
}

class _PanManagementSheetState extends ConsumerState<_PanManagementSheet> {
  final _panCtrl = TextEditingController();
  bool _obscure = true;
  bool _saved = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    if (user?.panNumber != null) {
      _panCtrl.text = user!.panNumber!;
    }
  }

  @override
  void dispose() {
    _panCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Rises with the keyboard; the scroll view lets the content adjust
      // instead of overflowing when space gets tight.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderMedium, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: AppColors.primaryBlue, size: 20),
                const SizedBox(width: 8),
                Text('PAN Management', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Your PAN is encrypted and only used to generate 80G tax certificates.', style: TextStyle(color: AppColors.textMedium, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: _panCtrl,
              obscureText: _obscure,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'PAN Number',
                hintText: 'ABCDE1234F',
                prefixIcon: const Icon(Icons.credit_card_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            if (_saved)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.forestGreen, size: 18),
                    SizedBox(width: 8),
                    Text('PAN saved securely!', style: TextStyle(color: AppColors.forestGreen, fontWeight: FontWeight.w600)),
                  ],
                ),
              ).animate().fadeIn().scaleXY(begin: 0.9, end: 1),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        final pan = _panCtrl.text.trim();
                        if (pan.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a PAN number'), backgroundColor: AppColors.errorRed),
                          );
                          return;
                        }

                        // Strict Indian PAN format regex check
                        final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
                        if (!panRegex.hasMatch(pan.toUpperCase())) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enter a valid PAN (e.g. ABCDE1234F)'), backgroundColor: AppColors.errorRed),
                          );
                          return;
                        }

                        setState(() => _isLoading = true);
                        try {
                          final user = ref.read(currentUserProvider);
                          if (user == null) throw Exception("User not found");

                          await ref.read(authNotifierProvider.notifier).updateProfile(
                                fullName: user.fullName ?? '',
                                email: user.email ?? '',
                                panNumber: pan,
                              );

                          if (!mounted) return;
                          setState(() {
                            _isLoading = false;
                            _saved = true;
                          });

                          Future.delayed(1500.ms, () {
                            if (!mounted) return;
                            Navigator.pop(context);
                          });
                        } catch (e) {
                          if (!mounted) return;
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to save PAN: $e'), backgroundColor: AppColors.errorRed),
                          );
                        }
                      },
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isLoading ? 'Saving...' : 'Save PAN Securely'),
                style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 80G Tax Vault Page ────────────────────────────────────────────────────────

final donationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.donations, requireAuth: true);
  final data = res['data'] as List<dynamic>;
  return data.map((e) => e as Map<String, dynamic>).toList();
});

class TaxVaultPage extends ConsumerWidget {
  const TaxVaultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final donationsAsync = ref.watch(donationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('80G Tax Vault'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.forestGreen.withAlpha(15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.forestGreen.withAlpha(50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.forestGreen, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Under Section 80G of the Income Tax Act, donations to BlueDot qualify for 50% tax deduction. Download your PDF receipts here.',
                    style: const TextStyle(color: AppColors.forestGreen, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 8),

          // Donation list
          Expanded(
            child: donationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error loading donations: $e')),
              data: (donations) {
                if (donations.isEmpty) {
                  return const Center(
                    child: Text('You have not made any donations yet.', style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  itemCount: donations.length,
                  itemBuilder: (_, i) => _DonationReceiptCard(data: donations[i])
                      .animate()
                      .fadeIn(delay: (100 * i).ms)
                      .slideY(begin: 0.05, end: 0, delay: (100 * i).ms),
                );
              },
            ),
          ),

          // Download all button — raised above the shell's floating nav bar
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 96),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All 80G receipts bundled — link sent to your email!'), backgroundColor: AppColors.forestGreen),
                  );
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download All 80G PDFs'),
                style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonationReceiptCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DonationReceiptCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'Pending';
    final isReady = status == 'Receipt Ready';
    final amount = data['amount'] != null ? (data['amount'] as num).toInt() : 0;
    final receiptId = data['receipt_id'] ?? data['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(data['campaign'] ?? 'General Donation', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isReady ? AppColors.forestGreen : AppColors.primaryYellow).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status as String,
                  style: TextStyle(
                    color: isReady ? AppColors.forestGreen : AppColors.warningAmber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryBlue, fontSize: 16)),
              const SizedBox(width: 12),
              Text(data['date'] as String, style: const TextStyle(color: AppColors.textMedium, fontSize: 13)),
            ],
          ),
          if (receiptId != null) ...[
            const SizedBox(height: 4),
            Text(receiptId as String, style: const TextStyle(color: AppColors.textLight, fontSize: 11, fontFamily: 'monospace')),
          ],
          if (isReady && data['receipt_url'] != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Downloading receipt $receiptId...'), backgroundColor: AppColors.forestGreen),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Download 80G PDF', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared layout components ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textLight,
            letterSpacing: 1.2,
          ),
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget trailing;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing = const SizedBox.shrink(),
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppColors.primaryBlue).withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor ?? AppColors.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textDark)),
                        if (subtitle != null)
                          Text(subtitle!, style: const TextStyle(color: AppColors.textMedium, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      );
}
