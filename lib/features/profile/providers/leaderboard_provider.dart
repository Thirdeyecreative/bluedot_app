import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/api_client.dart';

/// Fetches the live leaderboard from the backend.
///
/// ApiClient.get() returns already-decoded JSON (dynamic), not an
/// http.Response — so we cast it directly rather than checking statusCode.
/// If the request fails, ApiClient throws an [ApiException] which Riverpod
/// surfaces via the AsyncError state automatically.
final leaderboardProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get(ApiConfig.leaderboard) as List<dynamic>;
  return data.cast<Map<String, dynamic>>();
});
