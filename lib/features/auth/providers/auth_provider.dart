import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../data/auth_repository.dart';
import '../models/user_model.dart';


// True if a valid token exists AND the backend profile was fetched successfully
final authStateProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(authRepositoryProvider).getSavedUser();
  if (user == null && supabase.Supabase.instance.client.auth.currentSession != null) {
    // We have a Supabase session, but the backend fetch failed (e.g. backend down or user deleted).
    // Sign out locally to wipe the corrupted state and force them back to login.
    await supabase.Supabase.instance.client.auth.signOut();
  }
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
  AsyncValue<void> build() {
    // Listen to Supabase auth state changes to auto-refresh session state
    supabase.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == supabase.AuthChangeEvent.signedOut) {
        ref.read(currentUserProvider.notifier).set(null);
        ref.invalidate(authStateProvider);
      } else if (data.event == supabase.AuthChangeEvent.signedIn) {
        ref.invalidate(authStateProvider);
      }
    });
    return const AsyncValue.data(null);
  }

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

  Future<void> updateProfile({
    required String fullName,
    required String email,
    required String panNumber,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await _repo.updateProfile(
        fullName: fullName,
        email: email,
        panNumber: panNumber,
      );
      ref.read(currentUserProvider.notifier).set(user);
    });
  }

  Future<void> signOut() async {
    await _repo.signOut();
  }
}

