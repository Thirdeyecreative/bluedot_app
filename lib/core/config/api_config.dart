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
  static const String _envName = String.fromEnvironment('ENV', defaultValue: 'production');

  static AppEnv get env => switch (_envName) {
        'production' => AppEnv.production,
        'staging' => AppEnv.staging,
        _ => AppEnv.local,
      };

  /// Reads exactly like the mental model: true only on a production build.
  static bool get isProduction => env == AppEnv.production;

  // --- Per-environment base URLs ---
  static const String _localUrl = 'http://10.0.2.2:8000'; // Android emulator -> localhost
  static const String _stagingUrl = 'https://bluedot-backend-staging-426166329141.asia-south1.run.app';
  static const String _productionUrl = 'https://bluedot-backend-426166329141.asia-south1.run.app';

  static String get baseUrl => switch (env) {
        AppEnv.production => _productionUrl,
        AppEnv.staging => _stagingUrl,
        AppEnv.local => _localUrl,
      };

  static const String _v1 = '/api/v1';
  static String get _app => '$baseUrl$_v1/app';
  static String get _admin => '$baseUrl$_v1/admin';

  // App Auth
  static String get sendOtp => '$_app/auth/send-otp';
  static String get verifyOtp => '$_app/auth/login';

  // App Data
  static String get campaigns => '$_app/campaigns';
  static String get donations => '$_app/donations';
  static String get userProfile => '$_app/profile';
  static String get leaderboard => '$_app/leaderboard';

  // Scanner / Tree Tagging
  static String get scan => '$_app/tags/scan';
  static String get scanHistory => '$_app/tags/history';
  static String get mapData => '$_app/tags/map';

  // Crowdsourced Site Suggestions
  static String get suggestions => '$_app/suggestions';

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
