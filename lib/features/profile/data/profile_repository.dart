import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/demo/demo_data.dart';
import '../../../core/services/api_client.dart';
import '../../../core/config/api_config.dart';
import '../../auth/models/user_model.dart';
import '../models/badge_model.dart';
import '../models/certificate_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  Future<void> _demoDelay() => Future<void>.delayed(const Duration(milliseconds: 250));

  Future<AppUser> fetchProfile() async {
    await _demoDelay();
    return DemoData.user;
  }

  Future<List<Badge>> fetchBadges() async {
    await _demoDelay();
    return DemoData.badges;
  }

  Future<List<Map<String, dynamic>>> fetchLeaderboard() async {
    await _demoDelay();
    return DemoData.leaderboard;
  }

  Future<List<VolunteerCertificate>> fetchCertificates() async {
    try {
      final res = await _apiClient.get(ApiConfig.userCertificates, requireAuth: true);
      final list = res['data'] as List<dynamic>? ?? [];
      
      return list.map((e) => VolunteerCertificate(
        id: e['id'] as String,
        eventTitle: e['eventTitle'] as String,
        siteName: e['siteName'] as String,
        dateLabel: e['dateLabel'] as String,
        treesPlanted: e['treesPlanted'] as int,
        hours: e['hours'] as int,
        role: e['role'] as String,
        certificateNo: e['certificateNo'] as String,
      )).toList();
    } catch (e) {
      // Fallback to demo data if offline or no backend
      await _demoDelay();
      return DemoData.certificates;
    }
  }
}
