import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_feedback.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

class CheckoutPanField extends ConsumerStatefulWidget {
  const CheckoutPanField({super.key, this.manage = false});

  final bool manage;

  @override
  ConsumerState<CheckoutPanField> createState() => _CheckoutPanFieldState();
}

class _CheckoutPanFieldState extends ConsumerState<CheckoutPanField> {
  bool _busy = false;
  bool _opened = false;
  String? _message;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () {
      if (_opened && !_busy) _verify(check: true);
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _verify({required bool check}) async {
    if (_busy) return;
    final userId = ref.read(currentUserProvider)?.id;
    final repo = ref.read(authRepositoryProvider);
    setState(() { _busy = true; _message = null; });
    try {
      if (check) {
        final complete = await repo.finishPanVerification();
        if (!mounted) return;
        if (!complete) {
          setState(() => _message = 'Waiting for PAN consent in DigiLocker.');
          return;
        }
      } else {
        final result = await repo.startPanVerification(replace: widget.manage);
        if (!mounted) return;
        if (result['status'] != 'verified') {
          final link = Uri.parse(result['url'] as String);
          if (link.scheme != 'https' || !link.host.endsWith('.cashfree.com')) {
            throw const FormatException('Invalid consent link');
          }
          setState(() => _opened = true);
          if (!await launchUrl(link, mode: LaunchMode.externalApplication) && mounted) {
            setState(() => _message = 'Could not open DigiLocker. Try again.');
          }
          return;
        }
      }
      final refreshed = await repo.fetchCurrentUser();
      if (!mounted || ref.read(currentUserProvider)?.id != userId) return;
      ref.read(currentUserProvider.notifier).set(refreshed);
      setState(() => _opened = false);
    } catch (error) {
      if (mounted) setState(() => _message = AppFeedback.messageForError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final pan = user?.panNumber;
    final verified = user?.panVerified == true;
    final pending = _opened || user?.panVerificationPending == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(verified && pan != null && pan.length >= 4
            ? 'Verified PAN ending in ${pan.substring(pan.length - 4)}'
            : 'PAN verification required', style: Theme.of(context).textTheme.titleSmall),
        if (!verified || widget.manage) ...[
          const Text('Share your issued PAN through DigiLocker to verify your donor details.'),
          if (pending)
            TextButton(onPressed: _busy ? null : () => _verify(check: true),
              child: const Text('Check verification status')),
          OutlinedButton(onPressed: _busy ? null : () => _verify(check: false),
            child: Text(verified ? 'Change PAN with DigiLocker' : 'Verify with DigiLocker')),
        ] else
          const Text('Change in Settings → PAN Management'),
        if (_message != null) Text(_message!, semanticsLabel: _message),
      ],
    );
  }
}
