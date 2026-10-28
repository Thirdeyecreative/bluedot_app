import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import 'no_internet_page.dart';

/// Wraps the entire app in MaterialApp.builder to seamlessly display the NoInternetPage
/// whenever the connection drops, and automatically restores the underlying view with
/// 100% of user state preserved once the connection is restored.
class ConnectivityGate extends ConsumerWidget {
  final Widget child;

  const ConnectivityGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);

    return Stack(
      children: [
        child,
        if (!isOnline)
          const Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: NoInternetPage(isOverlay: true),
            ),
          ),
      ],
    );
  }
}
