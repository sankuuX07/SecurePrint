import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_desktop/core/config/app_config.dart';
import 'package:shop_desktop/providers/settings_provider.dart';
import 'package:shop_desktop/services/secure_storage.dart';

class MockSecureStorage extends SecureStorage {
  String? _env;
  String? _url;
  String? _authMode;

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

  @override
  Future<String?> getAuthMode() async => _authMode;

  @override
  Future<void> saveAuthMode(String mode) async {
    _authMode = mode;
  }
}

void main() {
  group('SettingsProvider Tests', () {
    late MockSecureStorage mockStorage;
    late SettingsProvider provider;

    setUp(() {
      AppConfig.currentEnvironment = Environment.development;
      AppConfig.authMode = AuthenticationMode.productionBackend;
      AppConfig.customBackendUrl = null;
      mockStorage = MockSecureStorage();
      provider = SettingsProvider(secureStorage: mockStorage);
    });

    test('Initializes with defaults when storage is empty', () async {
      await provider.init();
      expect(provider.isInitialized, true);
      // Fallback defaults: development and productionBackend
      expect(AppConfig.currentEnvironment, Environment.development);
      expect(AppConfig.authMode, AuthenticationMode.productionBackend);
      expect(AppConfig.backendUrl, 'http://127.0.0.1:8000');
      expect(AppConfig.enableDetailedLogging, isFalse);
      expect(AppConfig.customBackendUrl, isNull);
    });

    test('Loads saved environment and URL', () async {
      await mockStorage.saveEnvironment('production');
      await mockStorage.saveAuthMode('localDevelopment');
      await mockStorage.saveBackendUrl('https://api.test.com');
      
      await provider.init();
      
      expect(AppConfig.currentEnvironment, Environment.production);
      expect(AppConfig.authMode, AuthenticationMode.localDevelopment);
      expect(AppConfig.customBackendUrl, 'https://api.test.com');
    });

    test('setEnvironment saves value and clears URL', () async {
      await provider.setEnvironment(Environment.lanTesting);
      
      expect(AppConfig.currentEnvironment, Environment.lanTesting);
      expect(AppConfig.customBackendUrl, isNull);
      
      final savedEnv = await mockStorage.getEnvironment();
      expect(savedEnv, 'lanTesting');
    });

    test('setAuthMode saves and updates AppConfig', () async {
      await provider.setAuthMode(AuthenticationMode.localDevelopment);
      expect(AppConfig.authMode, AuthenticationMode.localDevelopment);
      expect(await mockStorage.getAuthMode(), 'localDevelopment');

      await provider.setAuthMode(AuthenticationMode.productionBackend);
      expect(AppConfig.authMode, AuthenticationMode.productionBackend);
      expect(await mockStorage.getAuthMode(), 'productionBackend');
    });

    test('setBackendUrl formats and saves URL', () async {
      await provider.setBackendUrl(' 192.168.1.50:8000/ ');
      
      // Should prepend http and strip trailing slash
      expect(AppConfig.customBackendUrl, 'http://192.168.1.50:8000');
      
      final savedUrl = await mockStorage.getBackendUrl();
      expect(savedUrl, 'http://192.168.1.50:8000');
    });

    test('checkBackendConnection returns true on HTTP 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Welcome to SecurePrint API'}), 200);
      });
      final customProvider = SettingsProvider(secureStorage: mockStorage, client: mockClient);
      final isOnline = await customProvider.checkBackendConnection();
      expect(isOnline, isTrue);
    });

    test('checkBackendConnection returns false on HTTP error or client exception', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });
      final customProvider = SettingsProvider(secureStorage: mockStorage, client: mockClient);
      final isOnline = await customProvider.checkBackendConnection();
      expect(isOnline, isFalse);
    });

    test('resetToDefaults restores development and productionBackend defaults', () async {
      await provider.setEnvironment(Environment.production);
      await provider.setAuthMode(AuthenticationMode.localDevelopment);
      await provider.setBackendUrl('http://custom-url:9000');

      await provider.resetToDefaults();

      expect(AppConfig.currentEnvironment, Environment.development);
      expect(AppConfig.authMode, AuthenticationMode.productionBackend);
      expect(AppConfig.customBackendUrl, isNull);
      expect(AppConfig.backendUrl, 'http://127.0.0.1:8000');
    });
  });
}
