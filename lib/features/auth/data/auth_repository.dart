import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/demo/demo_data.dart';
import '../../../core/services/storage_service.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(storageServiceProvider));
});

class AuthRepository {
  final StorageService _storage;

  AuthRepository(this._storage);

  Future<void> sendOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<AppUser> verifyOtp({required String phone, required String otp}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (otp != DemoData.demoOtp) {
      throw Exception('Invalid demo OTP. Use 123456.');
    }

    final user = DemoData.user;
    await _storage.saveToken(DemoData.demoToken);
    await _storage.saveUserInfo(phone: phone, name: user.fullName);
    return user;
  }

  Future<AppUser?> getSavedUser() async {
    final isLoggedIn = await _storage.isLoggedIn();
    if (!isLoggedIn) return null;
    return DemoData.user;
  }

  Future<void> signOut() => _storage.clearAll();
}
