import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../models/user_model.dart';

// True if a valid token exists
final authStateProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(authRepositoryProvider).getSavedUser();
  ref.read(currentUserProvider.notifier).set(user);
  return user != null;
});

// The current logged-in user state
final currentUserProvider = NotifierProvider<CurrentUserNotifier, AppUser?>(CurrentUserNotifier.new);

class CurrentUserNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;
  void set(AppUser? user) => state = user;

  void update({String? fullName, String? email, String? city}) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(fullName: fullName, email: email, city: city);
  }
}

// Auth actions notifier
final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(AuthNotifier.new);

class AuthNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> sendOtp(String phone) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.sendOtp(phone));
  }

  Future<AppUser?> verifyOtp({required String phone, required String otp}) async {
    state = const AsyncValue.loading();
    AppUser? user;
    state = await AsyncValue.guard(() async {
      user = await _repo.verifyOtp(phone: phone, otp: otp);
      ref.read(currentUserProvider.notifier).set(user);
    });
    return user;
  }

  Future<void> signOut() async {
    await _repo.signOut();
    ref.read(currentUserProvider.notifier).set(null);
    ref.invalidate(authStateProvider);
  }
}
