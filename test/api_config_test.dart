import 'package:bluedot_app/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an installation with a saved LAN backend upgrades to Cloud Run',
    () async {
      SharedPreferences.setMockInitialValues({
        'bluedot_custom_base_url': 'http://192.168.1.11:8000',
        'bluedot_selected_env': 'local',
      });
      await ApiConfig.init();
      expect(ApiConfig.env, AppEnv.production);
      expect(
        ApiConfig.appBanners,
        '${ApiConfig.productionUrl}/api/v1/app/banners',
      );

      await ApiConfig.setRuntimeBaseUrl(ApiConfig.stagingUrl);
      await ApiConfig.init();
      expect(ApiConfig.baseUrl, ApiConfig.stagingUrl);
    },
  );
}
