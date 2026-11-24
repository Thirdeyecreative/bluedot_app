import 'settings_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeletons.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../scanner/models/scan_result_model.dart';
import '../../scanner/providers/scanner_provider.dart';
import '../../scanner/widgets/scan_history_detail_sheet.dart';
import '../models/badge_model.dart';
import '../providers/profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authNotifierProvider.notifier).refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final badges = ref.watch(badgesProvider);

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_rounded, size: 56, color: AppColors.textLight),
              const SizedBox(height: 16),
              const Text('Not logged in'),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => context.go('/login'), child: const Text('Login')),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            await ref.read(authNotifierProvider.notifier).refreshProfile();
            ref.invalidate(badgesProvider);
          },
          color: AppColors.primaryBlue,
          child: CustomScrollView(
            slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('My Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Profile',
                onPressed: () => context.push('/profile/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.map_rounded),
                tooltip: 'My Eco Garden',
                onPressed: () => context.push('/map'),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: 'Settings',
                onPressed: () => context.push('/profile/settings'),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _ProfileHeader(user: user),
                _ImpactStats(user: user),
                _QuickActions(),
                _BadgesSection(badges: badges, onSeeAll: () => context.push('/profile/badges')),
                const ProfileAboutSection(),
                const ProfileLegalSection(),
                const ProfileTaxSection(),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    )));
  }
}

class _ProfileHeader extends ConsumerWidget {
  final AppUser user;
  const _ProfileHeader({required this.user});

  Future<void> _pickAndUploadImage(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryBlue),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryBlue),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Avatar',
          toolbarColor: AppColors.primaryBlue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Crop Avatar', aspectRatioLockEnabled: true),
      ],
    );

    if (cropped == null) return;
    
    // Show a snackbar while uploading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading avatar...')));
    }
    
    await ref.read(authNotifierProvider.notifier).uploadAvatar(File(cropped.path));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated successfully!')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, Color(0xFF2D3A8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withAlpha(70),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with level progress ring
          GestureDetector(
            onTap: () => _pickAndUploadImage(context, ref),
            child: CircularPercentIndicator(
              radius: 50,
              lineWidth: 5,
              percent: user.levelProgress.clamp(0.0, 1.0),
              progressColor: AppColors.primaryYellow,
              backgroundColor: Colors.white.withAlpha(40),
              circularStrokeCap: CircularStrokeCap.round,
              center: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(50), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: user.avatarUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user.avatarUrl!,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow)),
                          errorWidget: (context, url, error) => const Icon(Icons.person_rounded, color: Colors.white, size: 40),
                        ),
                      )
                    : const Icon(Icons.person_rounded, color: Colors.white, size: 40),
              ),
            ).animate().fadeIn().scaleXY(begin: 0.8, end: 1, curve: Curves.elasticOut),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(
            user.fullName ?? user.phone,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (user.city != null && user.city!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.primaryYellow, size: 14),
                const SizedBox(width: 4),
                Flexible(child: Text(
                  user.city!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                )),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryYellow.withAlpha(100)),
            ),
            child: Text(
              '${user.levelTitle}  ·  Level ${user.level}',
              style: const TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.hasLevelProgress
                ? '${user.pointsInCurrentLevel} / ${user.pointsForNextLevel} XP to Level ${user.level + 1}'
                : 'Level progress unavailable',
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12),
          ),
            ],
          )),
        ],
      ),
    );
  }
}

String _formatDonated(double val) {
  if (val >= 100000) return '₹${(val / 100000).toStringAsFixed(1)}L';
  if (val >= 1000) return '₹${(val / 1000).toStringAsFixed(1)}k';
  return '₹${val.toInt()}';
}

class _ImpactStats extends StatelessWidget {
  final AppUser user;
  const _ImpactStats({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Impact', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () => context.push('/profile/settings/tax-vault'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('80G Vault →', style: TextStyle(color: AppColors.forestGreen, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ImpactTile(
                icon: Icons.bolt_rounded,
                label: 'Total XP',
                value: '${user.totalPoints}',
                color: AppColors.primaryYellow,
              ),
              _ImpactTile(
                icon: Icons.park_rounded,
                label: 'Trees Tagged',
                value: '${user.treesTagged}',
                color: AppColors.forestGreen,
              ),
              _ImpactTile(
                icon: Icons.favorite_rounded,
                label: 'Donated',
                value: _formatDonated(user.totalDonated),
                color: AppColors.terracotta,
                onTap: () => context.push('/profile/settings/tax-vault'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.leaderboard_rounded,
                label: 'Leaderboard',
                sublabel: 'See your rank',
                color: AppColors.primaryBlue,
                onTap: () => context.push('/profile/leaderboard'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.workspace_premium_rounded,
                label: 'Certificates',
                sublabel: 'Your contributions',
                color: AppColors.terracotta,
                onTap: () => context.push('/profile/certificates'),
              ),
            ),
          ],
        ),
      );
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.sublabel, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
                  Text(sublabel, style: const TextStyle(color: AppColors.textMedium, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      );
}

class _ImpactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _ImpactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: content,
        ),
      );
    }

    return content;
  }
}

class _BadgesSection extends StatelessWidget {
  final AsyncValue<List<Badge>> badges;
  final VoidCallback onSeeAll;
  const _BadgesSection({required this.badges, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Badges', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              TextButton(onPressed: onSeeAll, child: const Text('See all')),
            ],
          ),
        ),
        badges.when(
          data: (list) => list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No badges available yet.'),
                )
              : SizedBox(
            height: 100,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: list.take(8).length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _BadgeChip(badge: list[i]),
            ),
          ),
          loading: () => const SkeletonRowCards(count: 4, height: 100, width: 90),
          error: (_, _) => const SizedBox(),
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final Badge badge;
  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: badge.unlocked ? 1.0 : 0.4,
      duration: 300.ms,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: badge.unlocked ? AppColors.primaryYellow.withAlpha(20) : AppColors.borderLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: badge.unlocked ? AppColors.primaryYellow.withAlpha(80) : AppColors.borderLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              badge.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: badge.unlocked ? AppColors.textDark : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScansHistory extends ConsumerStatefulWidget {
  const _ScansHistory({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<_ScansHistory> createState() => _ScansHistoryState();
}

class _ScansHistoryState extends ConsumerState<_ScansHistory> {
  int? _olderScansSkip;

  @override
  Widget build(BuildContext context) {
    final firstPageProvider = scanHistoryProvider((
      userId: widget.userId,
      skip: 0,
    ));
    final history = ref.watch(firstPageProvider);
    final hasOlderScans = history.asData?.value.hasMore == true;
    final skip = hasOlderScans ? _olderScansSkip : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Scans', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (hasOlderScans)
                TextButton(
                  onPressed: () => setState(() {
                    _olderScansSkip = skip == null
                        ? ScanHistoryPage.pageSize
                        : null;
                  }),
                  child: Text(
                    skip == null ? 'See all' : 'Show less',
                    semanticsLabel: skip == null
                        ? 'See all scans'
                        : 'Show fewer scans',
                  ),
                ),
            ],
          ),
        ),
        history.when(
          data: (page) {
            if (page.items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 40, color: AppColors.textLight),
                      SizedBox(height: 8),
                      Text('No scans yet! Use the Green Lens to identify plants.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMedium)),
                    ],
                  ),
                ),
              );
            }
            return _scanTiles(page.items);
          },
          loading: () => const SkeletonCardList(count: 3, height: 72),
          error: (_, _) => _loadError(() => ref.invalidate(firstPageProvider)),
        ),
        if (skip != null) _olderScans(skip),
      ],
    );
  }
  Widget _olderScans(int skip) {
    final provider = scanHistoryProvider((userId: widget.userId, skip: skip));
    final history = ref.watch(provider);
    const pageSize = ScanHistoryPage.pageSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Text(
            'Older Scans',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        history.when(
          data: (page) => page.items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('No more scans.'),
                )
              : _scanTiles(page.items),
          loading: () => const SkeletonCardList(count: 3, height: 72),
          error: (_, _) => _loadError(() => ref.invalidate(provider)),
        ),
        if (skip > pageSize || history.asData?.value.hasMore == true)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: skip > pageSize
                      ? () => setState(() => _olderScansSkip = skip - pageSize)
                      : null,
                  child: const Text('Previous'),
                ),
                TextButton(
                  onPressed: history.asData?.value.hasMore == true
                      ? () => setState(() => _olderScansSkip = skip + pageSize)
                      : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _scanTiles(List<ScanHistoryItem> items) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      children: [
        for (final item in items.take(ScanHistoryPage.pageSize))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ScanHistoryItemTile(item: item),
          ),
      ],
    ),
  );

  Widget _loadError(VoidCallback onRetry) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Couldn’t load scans.'),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _ScanHistoryItemTile extends StatelessWidget {
  final ScanHistoryItem item;
  const _ScanHistoryItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scientificName = item.species?.scientificName ?? item.plantnetData?.scientificName;
    final commonName = item.species?.localName ?? item.plantnetData?.commonName;
    final primaryLabel = commonName ?? scientificName ?? 'Unidentified plant';
    final secondaryLabel = [
      if (commonName != null && scientificName != null) scientificName,
      _formatScanDate(item.taggedAt),
    ].where((s) => s != null && s.isNotEmpty).join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ScanHistoryDetailSheet(item: item),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              if (item.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(item.imageUrl!, width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 52, height: 52)),
                )
              else
                Container(width: 52, height: 52, decoration: BoxDecoration(color: AppColors.forestGreen.withAlpha(20), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.eco_rounded, color: AppColors.forestGreen)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      secondaryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                item.status == 2 ? Icons.hourglass_top_rounded : item.status == 1 ? Icons.verified_rounded : Icons.cancel_rounded,
                color: item.status == 2 ? AppColors.warningAmber : item.status == 1 ? AppColors.forestGreen : Colors.red,
                size: 18,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textLight, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String? _formatScanDate(String? iso) {
    if (iso == null) return null;
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
class RecentScansPage extends ConsumerWidget {
  const RecentScansPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(appBar: AppBar(title: const Text('Your recent scans')), body: user == null
      ? const Center(child: Text('Sign in to see your scans.'))
      : ListView(children: [_ScansHistory(key: ValueKey(user.id), userId: user.id)]));
  }
}

class AboutBlueDotPage extends StatelessWidget {
  const AboutBlueDotPage({super.key});
  @override
  Widget build(BuildContext context) {
    const navy = Color(0xff0c142b);
    const cream = Color(0xfff6efdd);
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue, brightness: Brightness.dark)
          .copyWith(surface: navy, onSurface: cream, primary: AppColors.primaryYellow),
      scaffoldBackgroundColor: navy,
      textTheme: Theme.of(context).textTheme.apply(bodyColor: cream, displayColor: cream),
    );
    return Theme(data: theme, child: Builder(builder: (context) => Scaffold(
    appBar: AppBar(title: const Text('About BlueDot')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      Text('Our story so far', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Meet the team and learn about our mission.', textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset(
        'assets/images/profile/about_bluedot.webp', height: 224, fit: BoxFit.cover, semanticLabel: 'BlueDot emblem',
      )),
      const SizedBox(height: 24),
      Text('About BlueDot', style: theme.textTheme.titleLarge),
      const SizedBox(height: 12),
      const Text('BlueDot is a Bangalore-based nonprofit working to restore rivers, lakes, oceans and wetlands and protect the wildlife that depends on them. Environmentalists, scientists, educators and local residents came together out of concern for the effects of climate change.'),
      const SizedBox(height: 8),
      const Text('Legal entity: One Blu Foundation'),
      const SizedBox(height: 24),
      Center(child: DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xff18244a), borderRadius: BorderRadius.circular(24)),
        child: const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('MISSION & VALUES')),
      )),
      const SizedBox(height: 16),
      Text('We’re on a mission…', textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('We work toward climate-resilient habitats across India through hands-on restoration, scientific research, community engagement and education.', textAlign: TextAlign.center),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width < 300 ? width : (width - 12) / 2;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final (label, icon) in const [
            ('Project Ideation', Icons.lightbulb_outline),
            ('Project Implementation', Icons.volunteer_activism_outlined),
            ('Impact Assessment', Icons.monitor_heart_outlined),
            ('Volunteering', Icons.groups_outlined),
          ])
            Container(
              width: cardWidth, padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
              decoration: BoxDecoration(color: const Color(0xff102c33), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Icon(icon, color: const Color(0xff919fe6), size: 32),
                const SizedBox(height: 12),
                Text(label, textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
              ]),
            ),
        ]);
      }),
      const SizedBox(height: 24),
      Text('Meet our founder', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(color: const Color(0xff102c33), child: Image.asset(
          'assets/images/profile/harsha_tej.webp', height: 240, fit: BoxFit.contain,
          semanticLabel: 'Harsha Tej, founder of BlueDot',
        )),
      ),
      const SizedBox(height: 12),
      Text('Harsha Tej', style: Theme.of(context).textTheme.titleMedium),
      const Text('An environmentalist with a background in environmental science, Harsha has led restoration work across Karnataka for over a decade. He helped create and restore 18 lakes and led afforestation initiatives that planted over 1.5 lakh trees.'),
      const SizedBox(height: 24),
      Text('Our core team', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('Diganth Manchale · Vishlesh S P · Amit Shroff · Rammohan Paranjape · Rahul Aradhya · Himanshu Venugopal · Hitesh R J · Samarth S S · Sachin C S · Babu Chandra'),
      const SizedBox(height: 24),
      Text('Our projects', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      const Text('At Turahalli Forest, volunteers help clear litter from the forest. In Chennai, BlueDot’s mangrove planting work helps restore coastal habitat.'),
      TextButton(onPressed: () async {
        final opened = await launchUrl(Uri.parse('https://bluedot.ngo/projects'), mode: LaunchMode.externalApplication);
        if (!opened && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the projects page.')));
      }, child: const Text('Explore BlueDot projects')),
      OutlinedButton(onPressed: () async {
        final opened = await launchUrl(Uri.parse('https://bluedot.ngo/contact'), mode: LaunchMode.externalApplication);
        if (!opened && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the contact page.')));
      }, child: const Text('Contact BlueDot')),
    ]),
  )));
  }
}

