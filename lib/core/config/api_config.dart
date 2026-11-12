import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Backend environment selection.
///
/// The active environment is chosen at BUILD time or RUNTIME via app settings:
///
///   flutter run                                    -> local / auto-detected
///   flutter run --dart-define=ENV=local            -> local backend
///   flutter run --dart-define=ENV=staging          -> staging
///   flutter run --dart-define=API_HOST=192.168.1.7 -> explicit LAN IP
enum AppEnv { local, staging, production }

class ServerHealthResult {
  final bool isHealthy;
  final int statusCode;
  final int latencyMs;
  final String message;

  const ServerHealthResult({
    required this.isHealthy,
    required this.statusCode,
    required this.latencyMs,
    required this.message,
  });
}

class ApiConfig {
  ApiConfig._();

  // Compile-time flag injected via --dart-define=ENV=...
  static const String _envName = String.fromEnvironment(
    'ENV',
    defaultValue: 'local',
  );

  static const String _prefCustomBaseUrlKey = 'bluedot_custom_base_url';
  static const String _prefEnvKey = 'bluedot_selected_env';

  static String? _runtimeBaseUrl;
  static AppEnv? _runtimeEnv;

  /// Initializes runtime overrides stored in SharedPreferences.
  /// Must be called during app bootstrap (e.g. in main.dart).
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _runtimeBaseUrl = prefs.getString(_prefCustomBaseUrlKey);
      final savedEnv = prefs.getString(_prefEnvKey);
      if (savedEnv != null) {
        _runtimeEnv = switch (savedEnv) {
          'production' => AppEnv.production,
          'staging' => AppEnv.staging,
          'local' => AppEnv.local,
          _ => null,
        };
      }
    } catch (e) {
      debugPrint('[ApiConfig] Error loading persisted settings: $e');
    }
  }

  /// Sets or clears a custom runtime base URL (persisted across app restarts).
  static Future<void> setRuntimeBaseUrl(String? url) async {
    _runtimeBaseUrl = (url != null && url.trim().isNotEmpty) ? url.trim() : null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_runtimeBaseUrl != null) {
        await prefs.setString(_prefCustomBaseUrlKey, _runtimeBaseUrl!);
      } else {
        await prefs.remove(_prefCustomBaseUrlKey);
      }
    } catch (e) {
      debugPrint('[ApiConfig] Error saving custom base URL: $e');
    }
  }

  /// Sets or clears a runtime environment override (persisted across app restarts).
  static Future<void> setRuntimeEnv(AppEnv? newEnv) async {
    _runtimeEnv = newEnv;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (newEnv != null) {
        await prefs.setString(_prefEnvKey, newEnv.name);
      } else {
        await prefs.remove(_prefEnvKey);
      }
    } catch (e) {
      debugPrint('[ApiConfig] Error saving runtime env: $e');
    }
  }

  static AppEnv get env {
    if (_runtimeEnv != null) return _runtimeEnv!;
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
  static const String _apiPort = String.fromEnvironment('API_PORT', defaultValue: '8000');

  /// Developer machine Wi-Fi IPv4 address on the local network.
  /// Updated to match current DHCP lease (192.168.1.12).
  static const String currentLanIp = '192.168.1.12';

  /// Resolves the smartest local host for the current runtime platform:
  /// - Web / Desktop (Windows, macOS, Linux): 127.0.0.1
  /// - Mobile / Physical Device on Wi-Fi: 192.168.1.7
  static String get resolvedLocalHost {
    if (_apiHost.isNotEmpty) return _apiHost;
    if (kIsWeb) return '127.0.0.1';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return '127.0.0.1';
      case TargetPlatform.android:
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

  static String get stagingUrl => _stagingUrl;
  static String get productionUrl => _productionUrl;

  static String get baseUrl {
    if (_runtimeBaseUrl != null && _runtimeBaseUrl!.isNotEmpty) {
      return _runtimeBaseUrl!;
    }
    if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;
    return switch (env) {
      AppEnv.production => _productionUrl,
      AppEnv.staging => _stagingUrl,
      AppEnv.local => _localUrl,
    };
  }

  /// Actively checks server connectivity to the /health endpoint.
  static Future<ServerHealthResult> checkServerHealth([String? targetUrl]) async {
    final base = (targetUrl != null && targetUrl.trim().isNotEmpty) ? targetUrl.trim() : baseUrl;
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final uri = Uri.parse('$cleanBase/health');
    final sw = Stopwatch()..start();
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      sw.stop();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ServerHealthResult(
          isHealthy: true,
          statusCode: response.statusCode,
          latencyMs: sw.elapsedMilliseconds,
          message: 'Connected successfully (${sw.elapsedMilliseconds} ms)',
        );
      } else {
        return ServerHealthResult(
          isHealthy: false,
          statusCode: response.statusCode,
          latencyMs: sw.elapsedMilliseconds,
          message: 'Server responded with HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      sw.stop();
      return ServerHealthResult(
        isHealthy: false,
        statusCode: 0,
        latencyMs: sw.elapsedMilliseconds,
        message: 'Could not reach server: $e',
      );
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
  static String get campaigns => '$_app/campaigns';
  static String get donations => '$_app/donations';
  static String get initiateDonation => '$_app/donations/initiate';
  static String get verifyDonation => '$_app/donations/verify';
  static String get userProfile => '$_app/profile';
  static String get userCertificates => '$_app/profile/certificates';
  static String get notifications => '$_app/notifications';
  static String get markAllNotificationsRead => '$_app/notifications/mark-all-read';
  static String markNotificationRead(String id) => '$_app/notifications/$id/read';
  static String deleteNotification(String id) => '$_app/notifications/$id';
  static String get notificationDeviceToken => '$_app/notifications/device-token';
  static String get notificationPreferences => '$_app/notifications/preferences';
  static String get leaderboard => '$_app/leaderboard';
  static String get homeScreenConfig => '$_app/config';
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
