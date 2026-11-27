import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/app_update_service.dart';

class AppUpdateSheet extends StatefulWidget {
  const AppUpdateSheet._(this.update);

  final AppUpdate update;

  static Future<void> show(BuildContext context, AppUpdate update) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AppUpdateSheet._(update),
    );
  }

  @override
  State<AppUpdateSheet> createState() => _AppUpdateSheetState();
}

class _AppUpdateSheetState extends State<AppUpdateSheet> {
  bool _isStarting = false;
  bool _hasError = false;

  Future<void> _startUpdate() async {
    if (_isStarting) return;
    setState(() {
      _isStarting = true;
      _hasError = false;
    });

    try {
      final started = await widget.update.start();
      if (mounted && started && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = widget.update.version;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.system_update_rounded,
              color: AppColors.primaryBlue,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              'Update available',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              version == null
                  ? 'A new version of One blue is ready to install.'
                  : 'One blue $version is ready to install.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (_hasError) ...[
              const SizedBox(height: 12),
              const Text(
                'Couldn’t open the update. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.errorRed),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isStarting ? null : _startUpdate,
              child: Text(_isStarting ? 'Opening update…' : 'Update now'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          ],
        ),
      ),
    );
  }
}
