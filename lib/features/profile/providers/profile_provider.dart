import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/profile_repository.dart';
import '../models/badge_model.dart';
import '../models/certificate_model.dart';

final badgesProvider = FutureProvider<List<Badge>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchBadges();
});


final certificatesProvider = FutureProvider<List<VolunteerCertificate>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchCertificates();
});
