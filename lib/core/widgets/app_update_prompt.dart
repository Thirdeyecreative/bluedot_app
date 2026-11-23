import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/app_update_service.dart';
import '../services/connectivity_service.dart';
import 'app_update_sheet.dart';

class AppUpdatePrompt extends ConsumerStatefulWidget {
  const AppUpdatePrompt({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<AppUpdatePrompt> createState() => _AppUpdatePromptState();
}

class _AppUpdatePromptState extends ConsumerState<AppUpdatePrompt> {
  late final AppLifecycleListener _lifecycle;
  final _promptedReleases = <String>{};
  bool _promptScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_schedulePrompt);
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(appUpdateProvider),
    );
  }

  @override
  void didUpdateWidget(covariant AppUpdatePrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.router != oldWidget.router) {
      oldWidget.router.routerDelegate.removeListener(_schedulePrompt);
      widget.router.routerDelegate.addListener(_schedulePrompt);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_schedulePrompt);
    _lifecycle.dispose();
    super.dispose();
  }

  void _schedulePrompt() {
    if (_promptScheduled) return;
    _promptScheduled = true;

    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _promptScheduled = false;
      if (!mounted || binding.lifecycleState != AppLifecycleState.resumed) {
        return;
      }

      final delegate = widget.router.routerDelegate;
      final path = delegate.currentConfiguration.uri.path;
      if (path.isEmpty || path == '/splash' || path == '/no-internet') return;

      final update = ref.read(appUpdateProvider).value;
      final overlay = delegate.navigatorKey.currentState?.overlay;
      if (update == null ||
          overlay == null ||
          !ref.read(connectivityProvider)) {
        return;
      }
      if (!_promptedReleases.add(update.releaseId)) return;

      unawaited(AppUpdateSheet.show(overlay.context, update));
    });
    binding.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(appUpdateProvider).value != null) _schedulePrompt();
    return widget.child;
  }
}
