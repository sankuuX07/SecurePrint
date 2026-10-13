import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_desktop/core/config/app_config.dart';
import 'package:shop_desktop/services/auth_service.dart';
import 'package:shop_desktop/services/backend_auth_service.dart';
import 'package:shop_desktop/services/local_auth_service.dart';
import 'package:shop_desktop/services/secure_storage.dart';
import 'package:shop_desktop/providers/auth_provider.dart';

class MockSecureStorage extends SecureStorage {
  String? _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<String?> getToken() async {
    return _token;
  }

  @override
  Future<void> deleteToken() async {
    _token = null;
  }
}

void main() {
  group('AuthService Tests', () {
    test('Valid Shop login returns token', () async {
      final client = MockClient((request) async {
        return http.Response(
            jsonEncode({'access_token': 'fake_token', 'role': 'SHOP'}), 200);
      });
      final authService = AuthService(client: client);
      final token = await authService.login('shop@test.com', 'password');
      expect(token, 'fake_token');
    });

    test('Customer account attempting Shop login throws error', () async {
      final client = MockClient((request) async {
        return http.Response(
            jsonEncode({'access_token': 'fake_token', 'role': 'CUSTOMER'}), 200);
      });
      final authService = AuthService(client: client);
      expect(
          () => authService.login('cust@test.com', 'password'),
          throwsA(isA<AuthServiceException>()
              .having((e) => e.message, 'message', contains('Shop accounts only'))));
    });

    test('Admin account attempting Shop login throws error', () async {
      final client = MockClient((request) async {
        return http.Response(
            jsonEncode({'access_token': 'fake_token', 'role': 'ADMIN'}), 200);
      });
      final authService = AuthService(client: client);
      expect(
          () => authService.login('admin@test.com', 'password'),
          throwsA(isA<AuthServiceException>()
              .having((e) => e.message, 'message', contains('Shop accounts only'))));
    });

    test('Invalid credentials returns 400 error', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Incorrect email or password'}), 400);
      });
      final authService = AuthService(client: client);
      expect(
          () => authService.login('shop@test.com', 'wrong'),
          throwsA(isA<AuthServiceException>()
              .having((e) => e.message, 'message', contains('Incorrect email or password'))));
    });

    test('Backend unavailable throws error', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });
      final authService = AuthService(client: client);
      expect(
          () => authService.login('shop@test.com', 'password'),
          throwsA(isA<AuthServiceException>().having(
              (e) => e.message, 'message', contains('Unable to connect'))));
    });

    test('Empty backend URL throws configuration exception', () async {
      AppConfig.customBackendUrl = '';
      AppConfig.currentEnvironment = Environment.production;
      final authService = AuthService();
      expect(
        () => authService.login('shop@test.com', 'password'),
        throwsA(isA<AuthServiceException>().having(
          (e) => e.message,
          'message',
          contains('Backend URL is not configured'),
        )),
      );
    });
  });

  group('AuthProvider Tests', () {
    late MockSecureStorage mockStorage;

    setUp(() {
      AppConfig.currentEnvironment = Environment.development;
      AppConfig.authMode = AuthenticationMode.productionBackend;
      AppConfig.customBackendUrl = null;
      mockStorage = MockSecureStorage();
    });

    test('Backend authentication is the default mode with http://127.0.0.1:8000', () {
      final provider = AuthProvider(secureStorage: mockStorage);
      expect(AppConfig.authMode, AuthenticationMode.productionBackend);
      expect(AppConfig.backendUrl, 'http://127.0.0.1:8000');
      expect(provider.activeAuthService, isA<BackendAuthService>());
      expect(provider.isLocalSession, isFalse);
    });

    test('Missing username or password sets error message', () async {
      final provider = AuthProvider(secureStorage: mockStorage);
      await provider.login('', '');
      expect(provider.errorMessage, 'Please enter your email and password.');
      expect(provider.state, AuthState.unauthenticated);
    });

    test('Successful backend login sets state to authenticated with token', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:8000/api/v1/auth/login');
        return http.Response(
            jsonEncode({'access_token': 'fake_token', 'role': 'SHOP'}), 200);
      });
      final authService = AuthService(client: client);
      final provider = AuthProvider(authService: authService, secureStorage: mockStorage);
      
      await provider.login('shop@test.com', 'password');
      expect(provider.state, AuthState.authenticated);
      expect(provider.isLocalSession, isFalse);
      expect(await mockStorage.getToken(), 'fake_token');
    });

    test('Unavailable backend prevents false success and reports clear connection error', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });
      final backendAuth = BackendAuthService(client: client);
      final provider = AuthProvider(backendAuthService: backendAuth, secureStorage: mockStorage);

      await provider.login('shop@test.com', 'password');

      expect(provider.state, AuthState.unauthenticated);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.isLocalSession, isFalse);
      expect(provider.errorMessage, contains('Unable to connect to SecurePrint server'));
      expect(await mockStorage.getToken(), isNull);
    });

    test('Explicit offline mode selection routes to LocalAuthService', () async {
      AppConfig.authMode = AuthenticationMode.localDevelopment;
      final provider = AuthProvider(secureStorage: mockStorage);

      expect(provider.activeAuthService, isA<LocalAuthService>());
    });

    test('Non-SHOP role rejected and prevents authentication', () async {
      final client = MockClient((request) async {
        return http.Response(
            jsonEncode({'access_token': 'cust_token', 'role': 'CUSTOMER'}), 200);
      });
      final authService = AuthService(client: client);
      final provider = AuthProvider(authService: authService, secureStorage: mockStorage);

      await provider.login('customer@test.com', 'password');

      expect(provider.state, AuthState.unauthenticated);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.errorMessage, contains('Shop accounts only'));
      expect(await mockStorage.getToken(), isNull);
    });

    test('Successful logout removes token and sets state to unauthenticated', () async {
      final client = MockClient((request) async {
        return http.Response(
            jsonEncode({'access_token': 'fake_token', 'role': 'SHOP'}), 200);
      });
      final authService = AuthService(client: client);
      final provider = AuthProvider(authService: authService, secureStorage: mockStorage);
      
      await provider.login('shop@test.com', 'password');
      expect(provider.state, AuthState.authenticated);

      await provider.logout();
      expect(provider.state, AuthState.unauthenticated);
      expect(await mockStorage.getToken(), isNull);
    });

    test('Existing authenticated session restoration', () async {
      await mockStorage.saveToken('existing_token');
      final provider = AuthProvider(secureStorage: mockStorage);
      // Wait a microtask for initialization to finish
      await Future.delayed(Duration.zero);
      expect(provider.state, AuthState.authenticated);
    });
  });
}
