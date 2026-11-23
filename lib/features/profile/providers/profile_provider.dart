import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/profile_repository.dart';
import '../models/badge_model.dart';
import '../models/certificate_model.dart';

final badgesProvider = FutureProvider.autoDispose<List<Badge>>((ref) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (userId == null) return [];
  return ref.watch(profileRepositoryProvider).fetchBadges();
});


final certificatesProvider =
    FutureProvider.autoDispose<List<VolunteerCertificate>>((ref) async {
      final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (userId == null) return [];
  return ref.watch(profileRepositoryProvider).fetchCertificates();
});
