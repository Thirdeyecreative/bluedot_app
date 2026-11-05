import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../services/api_client.dart';

/// App-wide success / error feedback so every API response is surfaced to the
/// user consistently. Use [messageForError] to turn any thrown error into
/// human-readable copy, and the show* helpers for the actual UI.
class AppFeedback {
  AppFeedback._();

  /// Friendly message for any error. [ApiException]s already carry a
  /// user-ready message (see ApiClient); anything else gets a safe fallback.
  static String messageForError(Object error) {
    if (error is ApiException) return error.message;
    return 'Something went wrong. Please try again.';
  }

  /// Red, icon-led snackbar for failures.
  static void showError(BuildContext context, Object error) {
    final message = error is String ? error : messageForError(error);
    _showSnack(
      context,
      message: message,
      background: AppColors.errorRed,
      icon: Icons.error_outline_rounded,
    );
  }

  /// Green, icon-led snackbar for lightweight successes.
  static void showSuccess(BuildContext context, String message) {
    _showSnack(
      context,
      message: message,
      background: AppColors.forestGreen,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  static void _showSnack(
    BuildContext context, {
    required String message,
    required Color background,
    required IconData icon,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  /// Celebratory thank-you dialog for a meaningful contribution.
  ///
  /// Returns once the user dismisses it. Optionally shows an XP chip.
  static Future<void> showThankYou(
    BuildContext context, {
    required String title,
    required String message,
    String? xpLabel,
    String buttonLabel = 'Done',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.backgroundCream,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded, color: AppColors.forestGreen, size: 38),
              )
                  .animate()
                  .scaleXY(begin: 0.5, end: 1, duration: 500.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 250.ms),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textMedium),
              ),
              if (xpLabel != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryYellow.withAlpha(110)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, color: Color(0xFF8A7230), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        xpLabel,
                        style: const TextStyle(color: Color(0xFF8A7230), fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.3, end: 0, delay: 250.ms),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Empathetic and clear payment failure / cancellation dialog.
  /// Reassures the donor about their money and gives clear next steps.
  static Future<void> showPaymentFailed(
    BuildContext context, {
    required String reason,
    bool wasCancelled = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.backgroundCream,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Badge (Amber for user cancellation, Red for failure)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (wasCancelled ? Colors.amber : AppColors.errorRed).withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  wasCancelled ? Icons.warning_amber_rounded : Icons.highlight_off_rounded,
                  color: wasCancelled ? Colors.amber.shade800 : AppColors.errorRed,
                  size: 40,
                ),
              )
                  .animate()
                  .scaleXY(begin: 0.6, end: 1, duration: 400.ms, curve: Curves.easeOutBack)
                  .fadeIn(duration: 250.ms),
              const SizedBox(height: 18),
              // Title
              Text(
                wasCancelled ? 'Payment Cancelled' : 'Payment Incomplete',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              // Specific Reason
              Text(
                reason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(height: 18),
              // Money Reassurance Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withAlpha(15)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 20,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Money is Safe',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'If any amount was debited from your bank account or UPI app, it will be automatically refunded by your bank within 24 to 48 hours.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  /// Empathetic and interactive dialog for Pending / In-Progress / Under Review payments.
  /// Allows the donor to re-check the bank status with one tap.
  static Future<bool?> showPaymentPending(
    BuildContext context, {
    required String reason,
    bool isUnderReview = false,
    Future<bool> Function()? onCheckStatus,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PaymentPendingDialog(
        reason: reason,
        isUnderReview: isUnderReview,
        onCheckStatus: onCheckStatus,
      ),
    );
  }
}

class _PaymentPendingDialog extends StatefulWidget {
  final String reason;
  final bool isUnderReview;
  final Future<bool> Function()? onCheckStatus;

  const _PaymentPendingDialog({
    required this.reason,
    required this.isUnderReview,
    this.onCheckStatus,
  });

  @override
  State<_PaymentPendingDialog> createState() => _PaymentPendingDialogState();
}

class _PaymentPendingDialogState extends State<_PaymentPendingDialog> {
  bool _isChecking = false;
  late String _currentReason;

  @override
  void initState() {
    super.initState();
    _currentReason = widget.reason;
  }

  Future<void> _checkStatus() async {
    if (_isChecking || widget.onCheckStatus == null) return;
    setState(() => _isChecking = true);
    try {
      final success = await widget.onCheckStatus!();
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _isChecking = false;
        _currentReason = 'Still awaiting bank confirmation. You can check again or view it later in your profile.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _currentReason = 'Unable to verify status: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isUnderReview ? 'Payment Under Review' : 'Payment Processing';
    final badgeColor = widget.isUnderReview ? AppColors.primaryBlue : Colors.amber.shade700;

    return Dialog(
      backgroundColor: AppColors.backgroundCream,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Badge
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: widget.isUnderReview
                  ? Icon(Icons.verified_user_outlined, color: badgeColor, size: 38)
                  : Icon(Icons.hourglass_top_rounded, color: badgeColor, size: 38)
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .rotate(duration: 1500.ms, begin: -0.05, end: 0.05),
            )
                .animate()
                .scaleXY(begin: 0.6, end: 1, duration: 400.ms, curve: Curves.easeOutBack)
                .fadeIn(duration: 250.ms),
            const SizedBox(height: 18),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            // Specific Reason
            Text(
              _currentReason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textMedium,
              ),
            ),
            const SizedBox(height: 18),
            // Money Reassurance Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withAlpha(15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.forestGreen.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Money is Safe',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'If money was deducted from your account, it is securely held in the banking switch. Once confirmed, your donation and XP will be recorded automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            // Check Status Button (if supported)
            if (widget.onCheckStatus != null) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Check Status Now',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            // Secondary Dismiss button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Check Later in 80G Vault',
                  style: TextStyle(
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
