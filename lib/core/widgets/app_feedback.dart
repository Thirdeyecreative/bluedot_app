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
}
