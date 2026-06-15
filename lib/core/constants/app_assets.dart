/// Centralised asset path constants — keeps `assets/images/...` strings
/// out of page code and makes it obvious where to drop new webp images.
class AppAssets {
  AppAssets._();

  static const String _base = 'assets/images';

  // Home
  static const String greenLensButton = '$_base/home/green_lens_button.png';

  // Shared
  static const String bluedotSplashLogo = '$_base/shared/bluedot_splash_logo.png';
}
