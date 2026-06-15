import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/demo/demo_data.dart';
import '../../auth/models/user_model.dart';
import '../models/badge_model.dart';
import '../models/certificate_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

class ProfileRepository {
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
    await _demoDelay();
    return DemoData.certificates;
  }
}
