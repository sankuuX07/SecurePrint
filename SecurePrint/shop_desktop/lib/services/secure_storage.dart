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

  // Settings Configuration
  static const _backendUrlKey = 'secureprint_backend_url';
  static const _environmentKey = 'secureprint_environment';

  Future<void> saveBackendUrl(String url) async {
    await _storage.write(key: _backendUrlKey, value: url);
  }

  Future<String?> getBackendUrl() async {
    return await _storage.read(key: _backendUrlKey);
  }

  Future<void> saveEnvironment(String env) async {
    await _storage.write(key: _environmentKey, value: env);
  }

  Future<String?> getEnvironment() async {
    return await _storage.read(key: _environmentKey);
  }
  
  // Job Print State Configuration
  Future<void> saveJobPrintState(int jobId, String state) async {
    await _storage.write(key: 'secureprint_job_state_$jobId', value: state);
  }

  Future<String?> getJobPrintState(int jobId) async {
    return await _storage.read(key: 'secureprint_job_state_$jobId');
  }

  Future<void> deleteJobPrintState(int jobId) async {
    await _storage.delete(key: 'secureprint_job_state_$jobId');
  }

  // Auth Mode and Preferences
  static const _authModeKey = 'secureprint_auth_mode';
  static const _rememberEmailKey = 'secureprint_remember_email';
  static const _rememberSessionKey = 'secureprint_remember_session';
  static const _localUserKey = 'secureprint_active_local_user';

  Future<void> saveAuthMode(String mode) async {
    try {
      await _storage.write(key: _authModeKey, value: mode);
    } catch (_) {}
  }

  Future<String?> getAuthMode() async {
    try {
      return await _storage.read(key: _authModeKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRememberedEmail(String email) async {
    try {
      await _storage.write(key: _rememberEmailKey, value: email);
    } catch (_) {}
  }

  Future<String?> getRememberedEmail() async {
    try {
      return await _storage.read(key: _rememberEmailKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteRememberedEmail() async {
    try {
      await _storage.delete(key: _rememberEmailKey);
    } catch (_) {}
  }

  Future<void> saveRememberSession(bool remember) async {
    try {
      await _storage.write(key: _rememberSessionKey, value: remember ? 'true' : 'false');
    } catch (_) {}
  }

  Future<bool> getRememberSession() async {
    try {
      final val = await _storage.read(key: _rememberSessionKey);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteRememberSession() async {
    try {
      await _storage.delete(key: _rememberSessionKey);
    } catch (_) {}
  }

  Future<void> saveLocalUserData(String jsonStr) async {
    try {
      await _storage.write(key: _localUserKey, value: jsonStr);
    } catch (_) {}
  }

  Future<String?> getLocalUserData() async {
    try {
      return await _storage.read(key: _localUserKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteLocalUserData() async {
    try {
      await _storage.delete(key: _localUserKey);
    } catch (_) {}
  }
}
