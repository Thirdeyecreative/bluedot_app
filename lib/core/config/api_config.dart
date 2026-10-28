/// Backend environment selection.
///
/// The active environment is chosen at BUILD time, not in source, so a release
/// can never accidentally ship pointing at the wrong server:
///
///   flutter run                                    -> production (default)
///   flutter run --dart-define=ENV=local            -> local backend
///   flutter build apk --dart-define=ENV=staging    -> staging
enum AppEnv { local, staging, production }

class ApiConfig {
  ApiConfig._();

  // Compile-time flag injected via --dart-define=ENV=...
  static const String _envName = String.fromEnvironment(
    'ENV',
    defaultValue: 'local',
  );

  static AppEnv get env => switch (_envName) {
    'production' => AppEnv.production,
    'staging' => AppEnv.staging,
    _ => AppEnv.local,
  };

  /// Reads exactly like the mental model: true only on a production build.
  static bool get isProduction => env == AppEnv.production;

  // Compile-time optional overrides
  static const String _overrideBaseUrl = String.fromEnvironment('BASE_URL');
  // Default to machine's local Wi-Fi IP (192.168.1.33) so physical devices on Wi-Fi connect out-of-the-box.
  // Can be overridden via --dart-define=API_HOST=... or --dart-define=BASE_URL=...
  // Over USB with 'adb reverse tcp:8000 tcp:8000', use --dart-define=API_HOST=127.0.0.1
  static const String _apiHost = String.fromEnvironment('API_HOST', defaultValue: '192.168.1.33');
  static const String _apiPort = String.fromEnvironment('API_PORT', defaultValue: '8000');

  // --- Per-environment base URLs ---
  static String get _localUrl {
    if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;
    // Over Wi-Fi LAN: connects directly to http://192.168.1.33:8000
    // Over ADB reverse: pass --dart-define=API_HOST=127.0.0.1
    // Over Android Emulator: pass --dart-define=API_HOST=10.0.2.2
    return 'http://$_apiHost:$_apiPort';
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
  static String get userProfile => '$_app/profile';
  static String get userCertificates => '$_app/profile/certificates';
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
}
