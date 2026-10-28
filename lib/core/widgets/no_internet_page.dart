import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../services/connectivity_service.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/data/home_repository.dart';
import '../../features/home/providers/home_provider.dart';

class NoInternetPage extends ConsumerStatefulWidget {
  final bool isOverlay;
  final VoidCallback? onRetrySuccess;

  const NoInternetPage({
    super.key,
    this.isOverlay = false,
    this.onRetrySuccess,
  });

  @override
  ConsumerState<NoInternetPage> createState() => _NoInternetPageState();
}

class _NoInternetPageState extends ConsumerState<NoInternetPage> {
  bool _isChecking = false;
  String _statusText = 'Checking connection...';

  Future<void> _handleRetry() async {
    if (_isChecking) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isChecking = true;
      _statusText = 'Checking connection...';
    });

    try {
      // 1. Verify physical internet reachability WITHOUT prematurely changing connectivity state
      final isOnline = await ref
          .read(connectivityProvider.notifier)
          .checkConnection(updateState: false);

      if (!mounted) return;

      if (!isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Still offline. Please check your network and try again.'),
              ],
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // 2. Internet is verified online. Now preload the Home API content BEFORE un-gating!
      setState(() {
        _statusText = 'Loading latest content...';
      });

      // Invalidate existing stale home providers so fresh network calls run
      ref.invalidate(homeFeedProvider);
      ref.invalidate(blogsProvider);

      // Await both Home Feed (banners, campaigns, events) and Blogs
      final results = await Future.wait([
        ref.read(homeFeedProvider.future),
        ref.read(blogsProvider.future),
      ]).timeout(const Duration(seconds: 12));

      final feedData = results[0] as HomeFeedData?;

      // Refresh user profile in background if logged in
      try {
        await ref
            .read(authNotifierProvider.notifier)
            .refreshProfile()
            .timeout(const Duration(seconds: 4));
      } catch (_) {}

      if (!mounted) return;

      // 3. Confirm API content is successfully populated
      if (feedData != null) {
        // Mark as online NOW — this cleanly dismisses the ConnectivityGate overlay
        // since the Home screen underneath is ALREADY 100% loaded with API content!
        ref.read(connectivityProvider.notifier).setOnline(true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Connection restored! Welcome back.',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: AppColors.forestGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );

        if (widget.onRetrySuccess != null) {
          widget.onRetrySuccess!();
        } else if (!widget.isOverlay && context.canPop()) {
          context.pop();
        }
      } else {
        throw Exception('Feed data was null');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Connected to network, but failed to load content. Please try again.'),
              ),
            ],
          ),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(28, 24, 28, 28 + bottomInset),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Animated Visual Hero ─────────────────────────────────────
                _buildHeroIllustration(),

                const SizedBox(height: 36),

                // ── Headline & Copy ──────────────────────────────────────────
                Text(
                  "You're Offline",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.5,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 150.ms)
                    .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),

                const SizedBox(height: 12),

                Text(
                  "The trees are still growing, but your device has lost connection to the internet. Please check your Wi-Fi or mobile data to continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textMedium,
                    height: 1.5,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 250.ms)
                    .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),

                const SizedBox(height: 32),

                // ── Diagnostic Checklist Card ────────────────────────────────
                _buildDiagnosticCard()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 350.ms)
                    .scaleXY(begin: 0.95, end: 1.0, curve: Curves.easeOutBack),

                const SizedBox(height: 36),

                // ── Try Again CTA Button ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _handleRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isChecking
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _statusText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.refresh_rounded, size: 20),
                              SizedBox(width: 10),
                              Text(
                                "Try Again",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 450.ms)
                    .slideY(begin: 0.1, end: 0),

                // Optional Back button if routed as a subpage
                if (!widget.isOverlay && context.canPop()) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text(
                      "Go Back",
                      style: TextStyle(
                        color: AppColors.slateBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroIllustration() {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.terracotta.withAlpha(22),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(0.92, 0.92),
                end: const Offset(1.05, 1.05),
                duration: 2200.ms,
                curve: Curves.easeInOut,
              ),

          // Middle concentric ring
          Container(
            width: 135,
            height: 135,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryBlue.withAlpha(30),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(1.04, 1.04),
                end: const Offset(0.95, 0.95),
                duration: 1800.ms,
                curve: Curves.easeInOut,
              ),

          // Center solid badge
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryBlue,
                  AppColors.slateBlue,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withAlpha(80),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Colors.white,
              size: 42,
            ),
          )
              .animate()
              .scaleXY(begin: 0.6, end: 1.0, duration: 600.ms, curve: Curves.elasticOut),

          // Mini Eco Sprout Badge
          Positioned(
            right: 36,
            bottom: 34,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: AppColors.forestGreen,
                size: 18,
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 500.ms)
              .scaleXY(begin: 0.0, end: 1.0, curve: Curves.elasticOut),
        ],
      ),
    );
  }

  Widget _buildDiagnosticCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCheckRow(
            icon: Icons.wifi_rounded,
            title: "Check Wi-Fi or Mobile Data",
            subtitle: "Ensure your mobile data or Wi-Fi toggle is on",
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppColors.borderLight, height: 1),
          ),
          _buildCheckRow(
            icon: Icons.airplanemode_inactive_rounded,
            title: "Turn off Airplane Mode",
            subtitle: "Verify network signals aren't disabled",
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppColors.borderLight, height: 1),
          ),
          _buildCheckRow(
            icon: Icons.router_rounded,
            title: "Check Internet Gateway",
            subtitle: "Ensure your connection has active throughput",
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.forestGreen.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.forestGreen, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
