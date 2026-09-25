import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../services/supabase_auth_service.dart';
import '../models/user_model.dart';
import '../../../core/config/api_config.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    SupabaseAuthService(),
  );
});

class AuthRepository {
  final ApiClient _apiClient;
  final SupabaseAuthService _supabaseAuth;

  AuthRepository(this._apiClient, this._supabaseAuth);

  Future<void> sendOtp(String phone) async {
    await _supabaseAuth.sendOtp(phone);
  }

  Future<AppUser> verifyOtp({required String phone, required String otp}) async {
    final response = await _supabaseAuth.verifyOtp(phone, otp);
    if (response.session == null) {
      throw Exception("Verification failed. No session returned.");
    }
    return await fetchCurrentUser();
  }

  Future<AppUser> fetchCurrentUser() async {
    // Assuming GET /api/v1/app/profile returns the current user profile.
    // The ApiClient automatically injects the Supabase session token.
    final res = await _apiClient.get(ApiConfig.userProfile, requireAuth: true);
    return AppUser.fromJson(res['data'] ?? res);
  }

  Future<AppUser> updateProfile({
    required String fullName,
    required String email,
    required String panNumber,
  }) async {
    await _apiClient.put(
      ApiConfig.userProfile,
      data: {
        'full_name': fullName,
        'email': email,
        'pan_number': panNumber,
      },
      requireAuth: true,
    );
    return await fetchCurrentUser();
  }

  Future<AppUser> updatePreferences(Map<String, dynamic> preferences) async {
    await _apiClient.put(
      ApiConfig.userProfile,
      data: {
        'preferences': preferences,
      },
      requireAuth: true,
    );
    return await fetchCurrentUser();
  }

  Future<AppUser?> getSavedUser() async {
    if (_supabaseAuth.currentSession == null) return null;
    try {
      return await fetchCurrentUser();
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 404) {
        return null; // Session invalid or user deleted
      }
      rethrow; // Network error or 500 server error
    } catch (e) {
      rethrow; // Any other unexpected error
    }
  }

  Future<void> signOut() async {
    await _supabaseAuth.signOut();
  }

  Future<void> deleteProfile() async {
    await _apiClient.delete(ApiConfig.userProfile, requireAuth: true);
    await signOut(); // Clear local session after backend confirms deletion
  }
}

