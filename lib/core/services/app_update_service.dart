import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update_flutter/in_app_update_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'connectivity_service.dart';

class AppUpdate {
  final String releaseId;
  final String? version;
  final Future<bool> Function() start;

  const AppUpdate({required this.releaseId, this.version, required this.start});
}

final appUpdateProvider = FutureProvider<AppUpdate?>((ref) async {
  if (!ref.watch(connectivityProvider) || kIsWeb) return null;

  final store = InAppUpdateFlutter();
  try {
    final check = switch (defaultTargetPlatform) {
      TargetPlatform.android => _checkPlayStore(store),
      TargetPlatform.iOS => _checkAppStore(store),
      _ => Future<AppUpdate?>.value(),
    };
    return await check.timeout(const Duration(seconds: 12));
  } on PlatformException catch (error) {
    debugPrint('App update check unavailable (${error.code}).');
    return null;
  } on MissingPluginException {
    return null;
  } on TimeoutException {
    return null;
  }
});

Future<AppUpdate?> _checkPlayStore(InAppUpdateFlutter store) async {
  final info = await store.checkUpdateAndroid();
  final inProgress =
      info.updateAvailability ==
      UpdateAvailabilityAndroid.developerTriggeredUpdateInProgress;
  if (!inProgress &&
      info.updateAvailability != UpdateAvailabilityAndroid.updateAvailable) {
    return null;
  }

  return AppUpdate(
    releaseId: 'android:${info.availableVersionCode}',
    start: () async {
      if (info.isImmediateUpdateAllowed || inProgress) {
        try {
          final result = await store.startImmediateUpdateAndroid();
          if (result == UpdateResultAndroid.success) return true;
          if (result == UpdateResultAndroid.userCanceled) return false;
        } on PlatformException catch (error) {
          if (error.code == 'ALREADY_RUNNING') return false;
          debugPrint('Opening Google Play after update error (${error.code}).');
        }
      }

      final package = await PackageInfo.fromPlatform();
      return _openStore(
        Uri.https('play.google.com', '/store/apps/details', {
          'id': package.packageName,
        }),
      );
    },
  );
}

Future<AppUpdate?> _checkAppStore(InAppUpdateFlutter store) async {
  final info = await store.checkUpdateIos();
  if (info.updateAvailability != UpdateAvailabilityIos.updateAvailable) {
    return null;
  }

  return AppUpdate(
    releaseId: 'ios:${info.storeVersion}',
    version: info.storeVersion,
    start: () async {
      try {
        await store.showUpdateForIos(appStoreId: info.appStoreId);
        return true;
      } on PlatformException {
        return _openStore(
          Uri.https('apps.apple.com', '/app/id${info.appStoreId}'),
        );
      }
    },
  );
}

Future<bool> _openStore(Uri url) async {
  if (await launchUrl(url, mode: LaunchMode.externalApplication)) return true;
  throw StateError('Could not open the app store.');
}
