import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class OtpPage extends ConsumerStatefulWidget {
  final String phone;
  const OtpPage({super.key, required this.phone});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  // ── Debounce & cooldown guards ──────────────────────────────
  bool _isVerifying = false; // Prevents double-tap on Verify button
  bool _isResending = false; // Prevents spamming Resend
  int _resendCooldown = 0; // Seconds remaining until Resend is enabled
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown(); // Start 30s cooldown on page load
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  // ── Resend cooldown logic ───────────────────────────────────
  void _startResendCooldown() {
    _resendCooldown = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _resendOtp() async {
    if (_isResending || _resendCooldown > 0) return;
    setState(() => _isResending = true);
    try {
      await ref.read(authNotifierProvider.notifier).sendOtp(widget.phone);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP resent successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        _startResendCooldown();
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ── OTP verification with debounce guard ────────────────────
  Future<void> _verify() async {
    if (_otp.length < 6) return;
    if (_isVerifying) return; // ← Prevents double-call from auto-submit + button tap

    setState(() => _isVerifying = true);
    try {
      final user = await ref.read(authNotifierProvider.notifier).verifyOtp(
        phone: widget.phone,
        otp: _otp,
      );

      if (!mounted) return;
      final authState = ref.read(authNotifierProvider);

      if (authState.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.error.toString()),
            backgroundColor: AppColors.errorRed,
          ),
        );
      } else if (user != null) {
        // Invalidate auth state so the router re-evaluates.
        // GoRouter's redirect will decide where to send us:
        //   - /complete-profile  (if fullName is null or empty)
        //   - /home              (if profile is already complete)
        ref.invalidate(authStateProvider);
        // Do NOT manually context.go('/home') — let the router handle it.
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-submit when all 6 digits are entered
    if (_otp.length == 6) _verify();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading spinner from either the provider state OR our local guard
    final providerLoading = ref.watch(authNotifierProvider).isLoading;
    final isLoading = providerLoading || _isVerifying;

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Enter OTP',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ).animate().fadeIn().slideY(begin: 0.2, end: 0),
              const SizedBox(height: 8),
              Text(
                'Sent to ${widget.phone}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textMedium),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 40),
              Row(
                children: [
                  for (int i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 48),
                          child: _OtpBox(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            onChanged: (v) => _onChanged(v, i),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _verify,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify & Continue'),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: (_resendCooldown > 0 || _isResending) ? null : _resendOtp,
                  child: Text(
                    _resendCooldown > 0
                        ? 'Resend OTP in ${_resendCooldown}s'
                        : (_isResending ? 'Sending...' : 'Resend OTP'),
                    style: TextStyle(
                      color: (_resendCooldown > 0 || _isResending)
                          ? AppColors.textLight
                          : AppColors.primaryBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
        onChanged: onChanged,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
          ),
        ),
      ),
    );
  }
}
