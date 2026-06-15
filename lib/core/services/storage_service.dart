import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

class StorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static const _tokenKey = 'auth_token';
  static const _phoneKey = 'user_phone';
  static const _nameKey = 'user_name';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<void> saveUserInfo({required String phone, String? name}) async {
    await _storage.write(key: _phoneKey, value: phone);
    if (name != null) await _storage.write(key: _nameKey, value: name);
  }

  Future<String?> getUserPhone() => _storage.read(key: _phoneKey);
  Future<String?> getUserName() => _storage.read(key: _nameKey);

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() => _storage.deleteAll();
}
