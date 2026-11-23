import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Backend environment selection.
///
/// Choose the environment at build time. Release builds default to production.
///
///   flutter run                                    -> local (Android uses USB forwarding)
///   flutter run --dart-define=ENV=local            -> local backend
///   flutter run --dart-define=ENV=staging          -> staging
///   flutter run --dart-define=API_HOST=192.168.1.44 -> explicit LAN IP
enum AppEnv { local, staging, production }

class ApiConfig {
  ApiConfig._();

  // Compile-time flag injected via --dart-define=ENV=...
  static const String _envName = String.fromEnvironment(
    'ENV',
    defaultValue: kReleaseMode ? 'production' : 'local',
  );

  static AppEnv get env {
    return switch (_envName) {
      'production' => AppEnv.production,
      'staging' => AppEnv.staging,
      _ => AppEnv.local,
    };
  }

  /// Reads exactly like the mental model: true only on a production build.
  static bool get isProduction => env == AppEnv.production;

  // Compile-time optional overrides
  static const String _overrideBaseUrl = String.fromEnvironment('BASE_URL');
  static const String _apiHost = String.fromEnvironment('API_HOST');
  static const String _apiPort = String.fromEnvironment(
    'API_PORT',
    defaultValue: '8000',
  );

  /// Default Wi-Fi address of the local API server for physical iOS devices.
  static const String currentLanIp = '192.168.1.44';

  /// Resolves the local API host for the current platform:
  /// - Web / Desktop (Windows, macOS, Linux): 127.0.0.1
  /// - Android over USB: 127.0.0.1 via `adb reverse tcp:8000 tcp:8000`
  /// - iOS on Wi-Fi: [currentLanIp]
  static String get resolvedLocalHost {
    if (_apiHost.isNotEmpty) return _apiHost;
    if (kIsWeb) return '127.0.0.1';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.android:
        return '127.0.0.1';
      case TargetPlatform.iOS:
      default:
        return currentLanIp;
    }
  }

  // --- Per-environment base URLs ---
  static String get _localUrl {
    return 'http://$resolvedLocalHost:$_apiPort';
  }

  static const String _stagingUrl =
      'https://bluedot-backend-staging-426166329141.asia-south1.run.app';
  static const String _productionUrl =
      'https://bluedot-backend-426166329141.asia-south1.run.app';

  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;
    return switch (env) {
      AppEnv.production => _productionUrl,
      AppEnv.staging => _stagingUrl,
      AppEnv.local => _localUrl,
    };
  }

  /// Actively checks server connectivity to the /health endpoint.
  static Future<bool> checkServerHealth() async {
    final base = baseUrl;
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    try {
      final response = await http
          .get(Uri.parse('$cleanBase/health'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static const String _v1 = '/api/v1';
  static String get _app => '$baseUrl$_v1/app';
  static String get _admin => '$baseUrl$_v1/admin';

  // App Auth
  static String get sendOtp => '$_app/auth/send-otp';
  static String get verifyOtp => '$_app/auth/login';

  // App Data
  static String get homeFeed => '$_app/home-feed';
  static String get ecoVitals => '$_app/eco-vitals';
  static String get campaigns => '$_app/campaigns';
  static String get donations => '$_app/donations';
  static String get donationPolicy => '$_app/donations/policy';
  static String get initiateDonation => '$_app/donations/initiate';
  static String get verifyDonation => '$_app/donations/verify';
  static String get userProfile => '$_app/profile';
  static String get userBadges => '$_app/profile/badges';
  static String get userCertificates => '$_app/profile/certificates';
  static String get notifications => '$_app/notifications';
  static String get markAllNotificationsRead => '$_app/notifications/mark-all-read';
  static String markNotificationRead(String id) => '$_app/notifications/$id/read';
  static String deleteNotification(String id) => '$_app/notifications/$id';
  static String get notificationDeviceToken => '$_app/notifications/device-token';
  static String get notificationPreferences => '$_app/notifications/preferences';
  static String get leaderboard => '$_app/leaderboard';
  static String get appBanners => '$_app/banners';
  static String get directoryData => '$_app/directory';
  static String get appBlogs => '$_app/blogs';
  static String appBlogDetail(String slugOrId) => '$_app/blogs/$slugOrId';

  // Scanner / Tree Tagging
  static String get scan => '$_app/tags/scan';
  static String get scanHistory => '$_app/tags/history';
  static String get mapData => '$_app/tags/map';

  // Crowdsourced Site Suggestions
  static String get suggestions => '$_app/suggestions';

  // Events / Upcoming Drives
  static String get appEvents => '$_app/events';
  static String appEventDetail(String id) => '$_app/events/$id';
  static String appEventRsvp(String id) => '$_app/events/$id/rsvp';
  static String appEventVolunteer(String id) => '$_app/events/$id/volunteer';
  static String get appEventCheckin => '$_app/events/checkin';
  static String get appEventCheckout => '$_app/events/checkout';
  static String appEventDonate(String id) => '$_app/events/$id/donate';

  // Content (Admin-served public content)
  static String get blogs => '$_admin/blogs';
  static String get banners => '$_admin/content/banners';
  static String get trees => '$_admin/operations/trees';
  static String get events => '$_admin/operations/events';
  static String get upcomingEvents => '$_admin/dashboard/events/upcoming';

  // Gamification
  static String get badges => '$_admin/content/gamification/badges';
  static String get gamificationRules => '$_admin/content/gamification/rules';

  // Legal & Privacy Compliance
  static String legalDocument(String slug) => '$_app/legal/documents/$slug';
  static String get consentStatus => '$_app/legal/consent-status';
  static String get recordConsent => '$_app/legal/consent';
  static String get privacyRequest => '$_app/legal/privacy-request';
}
