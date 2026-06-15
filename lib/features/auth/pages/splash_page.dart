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
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final isLoggedIn = await ref.read(authStateProvider.future);
    if (!mounted) return;
    context.go(isLoggedIn ? '/home' : '/login');
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
          ],
        ),
      ),
    );
  }
}
