import 'package:flutter_test/flutter_test.dart';
import 'package:shop_desktop/core/config/app_config.dart';
import 'package:shop_desktop/providers/settings_provider.dart';
import 'package:shop_desktop/services/secure_storage.dart';

class MockSecureStorage extends SecureStorage {
  String? _env;
  String? _url;

  @override
  Future<String?> getEnvironment() async => _env;

  @override
  Future<void> saveEnvironment(String env) async {
    _env = env;
  }

  @override
  Future<String?> getBackendUrl() async => _url;

  @override
  Future<void> saveBackendUrl(String url) async {
    _url = url;
  }
}

void main() {
  group('SettingsProvider Tests', () {
    late MockSecureStorage mockStorage;
    late SettingsProvider provider;

    setUp(() {
      mockStorage = MockSecureStorage();
      provider = SettingsProvider(secureStorage: mockStorage);
    });

    test('Initializes with defaults when storage is empty', () async {
      await provider.init();
      expect(provider.isInitialized, true);
      // Fallback defaults
      expect(AppConfig.currentEnvironment, Environment.production);
      expect(AppConfig.enableDetailedLogging, isFalse);
      expect(AppConfig.customBackendUrl, isNull);
    });

    test('Loads saved environment and URL', () async {
      await mockStorage.saveEnvironment('production');
      await mockStorage.saveBackendUrl('https://api.test.com');
      
      await provider.init();
      
      expect(AppConfig.currentEnvironment, Environment.production);
      expect(AppConfig.customBackendUrl, 'https://api.test.com');
    });

    test('setEnvironment saves value and clears URL', () async {
      await provider.setEnvironment(Environment.lanTesting);
      
      expect(AppConfig.currentEnvironment, Environment.lanTesting);
      expect(AppConfig.customBackendUrl, isNull);
      
      final savedEnv = await mockStorage.getEnvironment();
      expect(savedEnv, 'lanTesting');
    });

    test('setBackendUrl formats and saves URL', () async {
      await provider.setBackendUrl(' 192.168.1.50:8000/ ');
      
      // Should prepend http and strip trailing slash
      expect(AppConfig.customBackendUrl, 'http://192.168.1.50:8000');
      
      final savedUrl = await mockStorage.getBackendUrl();
      expect(savedUrl, 'http://192.168.1.50:8000');
    });
  });
}
