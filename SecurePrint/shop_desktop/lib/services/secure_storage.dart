import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'secureprint_shop_auth_token';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // Printer Configuration
  static const _printerKey = 'secureprint_preferred_printer';

  Future<void> savePreferredPrinter(String printerName) async {
    await _storage.write(key: _printerKey, value: printerName);
  }

  Future<String?> getPreferredPrinter() async {
    return await _storage.read(key: _printerKey);
  }
}
