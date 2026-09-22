import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    setState(() => _hasError = false);
    try {
      // Run both the animation delay and the network fetch concurrently
      final authFuture = ref.read(authStateProvider.future);
      final delayFuture = Future.delayed(const Duration(milliseconds: 2200));

      final results = await Future.wait([authFuture, delayFuture]);
      final isLoggedIn = results[0] as bool;

      if (!mounted) return;
      context.go(isLoggedIn ? '/home' : '/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AppAssets.bluedotSplashLogo,
              width: (MediaQuery.of(context).size.width * 0.62).clamp(200.0, 300.0),
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .scaleXY(begin: 0.8, end: 1, duration: 700.ms, curve: Curves.elasticOut),
            const SizedBox(height: 12),
            Text(
              'Climate Action, Gamified.',
              style: TextStyle(
                color: Colors.white.withAlpha(220),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            )
                .animate()
                .fadeIn(delay: 700.ms, duration: 600.ms),
            if (_hasError) ...[
              const SizedBox(height: 48),
              const Text(
                'Cannot connect to servers.\nPlease check your internet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(authStateProvider);
                  _navigate();
                },
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryBlue),
                label: const Text('Retry Connection', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
            ],
          ],
        ),
      ),
    );
  }
}
