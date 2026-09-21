import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Sends an OTP to the given phone number via Supabase Auth (which triggers MSG91).
  Future<void> sendOtp(String phone) async {
    try {
      await _supabase.auth.signInWithOtp(
        phone: phone,
      );
    } catch (e) {
      // Re-throw or handle custom exceptions based on error codes
      throw Exception('Failed to send OTP: $e');
    }
  }

  /// Verifies the 6-digit OTP code entered by the user.
  Future<AuthResponse> verifyOtp(String phone, String code) async {
    try {
      final AuthResponse response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: code,
        type: OtpType.sms,
      );
      return response;
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

  /// Signs out the current user and clears the session.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Exposes the auth state change stream for Riverpod to listen to.
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  /// Returns the current session, if any.
  Session? get currentSession => _supabase.auth.currentSession;
}
