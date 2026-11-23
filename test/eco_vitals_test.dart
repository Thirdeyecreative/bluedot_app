import 'package:bluedot_app/core/config/api_config.dart';
import 'package:bluedot_app/core/services/api_client.dart';
import 'package:bluedot_app/core/services/storage_service.dart';
import 'package:bluedot_app/features/auth/models/user_model.dart';
import 'package:bluedot_app/features/auth/providers/auth_provider.dart';
import 'package:bluedot_app/features/home/providers/home_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProfileUser extends CurrentUserNotifier {
  @override
  AppUser build() => AppUser.fromJson({'id': 'eco-user', 'city': 'Mysore'});
}

class _EcoApi extends ApiClient {
  _EcoApi({this.unavailable = false}) : super(StorageService());

  final bool unavailable;
  int calls = 0;

  @override
  Future<dynamic> get(
    String url, {
    bool requireAuth = true,
    Map<String, String>? query,
  }) async {
    calls++;
    expect(url, ApiConfig.ecoVitals);
    expect(requireAuth, isFalse);
    expect(query, {'city': 'Mysore'});
    if (unavailable) {
      throw const ApiException(message: 'Unavailable', statusCode: 503);
    }
    return {
      'city': 'Mysore',
      'aqi': 103,
      'status': 'Sensitive',
      'recommendation': 'Server air quality guidance',
      'uv_index': 0,
      'uv_status': 'Low',
      'uv_advisory': 'Server UV guidance',
      'temperature': 31,
      'feels_like': 33,
      'humidity': 72,
      'comfort_status': 'Humid Air',
      'canopy_metrics': {'platform_trees': 7, 'estimated_co2_kg': 154},
    };
  }
}

ProviderContainer _container(_EcoApi api) => ProviderContainer.test(
  overrides: [
    currentUserProvider.overrideWith(_ProfileUser.new),
    apiClientProvider.overrideWithValue(api),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Eco Vitals sends the profile city and renders API readings', () async {
    final api = _EcoApi();
    final container = _container(api);

    final readings = await container.read(cityAqiProvider.future);
    expect(readings.aqi, 103);
    expect(readings.uvIndex, 0);
    expect(readings.temperature, 31);
    expect(readings.platformTrees, 7);
    expect(api.calls, 1);
  });

  test('Eco Vitals reports API errors without substituting readings', () async {
    final api = _EcoApi(unavailable: true);
    final container = _container(api);

    await expectLater(
      container.read(cityAqiProvider.future),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(cityAqiProvider).value, isNull);
    expect(api.calls, 1);
  });
}
