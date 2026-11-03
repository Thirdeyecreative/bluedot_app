import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../services/legal_service.dart';

/// Non-skippable bottom sheet shown when an admin publishes a new policy version
/// requiring mandatory re-consent.
class PolicyUpdateSheet extends ConsumerStatefulWidget {
  final List<PendingConsentModel> pendingDocuments;

  const PolicyUpdateSheet({
    super.key,
    required this.pendingDocuments,
  });

  /// Displays the modal bottom sheet strictly non-dismissible.
  static Future<void> show(BuildContext context, List<PendingConsentModel> pendingDocs) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PolicyUpdateSheet(pendingDocuments: pendingDocs),
    );
  }

  @override
  ConsumerState<PolicyUpdateSheet> createState() => _PolicyUpdateSheetState();
}

class _PolicyUpdateSheetState extends ConsumerState<PolicyUpdateSheet> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _acceptAll() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final service = ref.read(legalServiceProvider);
    bool allSucceeded = true;

    for (final doc in widget.pendingDocuments) {
      final ok = await service.recordConsent(doc.slug, doc.version);
      if (!ok) {
        allSucceeded = false;
        break;
      }
    }

    if (!mounted) return;

    if (allSucceeded) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Could not record your agreement. Please check your network connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disables back button / swipe back gestures entirely
      child: Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon Header
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primaryBlue,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Updated Terms & Policies',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                'We have updated our platform policies to ensure continued transparency and compliance with data protection standards. Please review and accept the latest versions to continue:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // Documents List
              ...widget.pendingDocuments.map((doc) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCream,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryBlue.withAlpha(30)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, color: AppColors.primaryBlue, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (doc.changeSummary != null && doc.changeSummary!.isNotEmpty)
                              Text(
                                doc.changeSummary!,
                                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'v${doc.version}',
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primaryBlue),
                        onPressed: () {
                          context.push(doc.slug == 'privacy' ? '/privacy' : '/terms');
                        },
                      ),
                    ],
                  ),
                );
              }),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12.5),
                ),
              ],

              const SizedBox(height: 20),

              // Non-skippable Action Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _acceptAll,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Text(
                          'I Agree & Continue',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

