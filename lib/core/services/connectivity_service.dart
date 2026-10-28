import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityNotifier extends Notifier<bool> {
  Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicTimer;

  @override
  bool build() {
    _connectivity = Connectivity();

    _subscription = _connectivity!.onConnectivityChanged.listen((results) {
      if (results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none)) {
        state = false;
      } else {
        checkConnection();
      }
    });

    // Check periodically every 20s to detect captive portals or dead Wi-Fi
    _periodicTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      checkConnection();
    });

    ref.onDispose(() {
      _subscription?.cancel();
      _periodicTimer?.cancel();
    });

    // Run initial verification
    Future.microtask(() => checkConnection());

    // Default to true on startup to prevent flickering before first ping completes
    return true;
  }

  /// Actively checks for working internet connectivity via DNS resolution.
  /// [updateState]: if false, checks reachability without updating [state].
  Future<bool> checkConnection({bool updateState = true}) async {
    try {
      final results = await _connectivity?.checkConnectivity();
      if (results == null || results.isEmpty || (results.length == 1 && results.first == ConnectivityResult.none)) {
        if (updateState && state != false) state = false;
        return false;
      }

      // Verify real throughput with quick DNS lookup
      final hostResult = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 3500));
      final online = hostResult.isNotEmpty && hostResult[0].rawAddress.isNotEmpty;

      if (updateState) {
        // If we are currently offline (gated by NoInternetPage), do NOT automatically un-gate
        // in the background without preloading the API content first!
        if (!state && online) {
          return true;
        }
        if (state != online) state = online;
      }
      return online;
    } catch (_) {
      if (updateState && state != false) state = false;
      return false;
    }
  }

  /// Explicitly sets the online/offline state
  void setOnline(bool online) {
    if (state != online) state = online;
  }

  /// Immediately marks the connection as offline when a network socket error occurs
  void reportNetworkFailure() {
    if (state != false) state = false;
  }
}

/// Provides whether the device currently has active internet (true = online, false = offline)
final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(ConnectivityNotifier.new);
