import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../../core/config/api_config.dart';
import '../models/badge_model.dart';
import '../models/certificate_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  Future<List<Badge>> fetchBadges() async {
    final res = await _apiClient.get(ApiConfig.userBadges);
    return (res['data'] as List<dynamic>)
        .map((item) => Badge.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<VolunteerCertificate>> fetchCertificates() async {
    final res = await _apiClient.get(ApiConfig.userCertificates);
    final list = res['data'] as List<dynamic>;
    return list.map((item) => VolunteerCertificate(
      id: item['id'] as String,
      eventTitle: item['eventTitle'] as String,
      siteName: item['siteName'] as String,
      dateLabel: item['dateLabel'] as String,
      treesPlanted: item['treesPlanted'] as int,
      hours: item['hours'] as int,
      role: item['role'] as String,
      certificateNo: item['certificateNo'] as String,
      downloadUrl: item['downloadUrl'] as String? ?? item['download_url'] as String?,
      verificationUrl: item['verificationUrl'] as String? ?? item['verification_url'] as String?,
    )).toList();
  }
}
