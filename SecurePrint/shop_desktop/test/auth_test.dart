import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_desktop/services/auth_service.dart';
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
  });

  group('AuthProvider Tests', () {
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
    });

    test('Missing username or password sets error message', () async {
      final provider = AuthProvider(secureStorage: mockStorage);
      await provider.login('', '');
      expect(provider.errorMessage, 'Please enter your email and password.');
      expect(provider.state, AuthState.unauthenticated);
    });

    test('Successful login sets state to authenticated', () async {
      final client = MockClient((request) async {
        return http.Response(
            jsonEncode({'access_token': 'fake_token', 'role': 'SHOP'}), 200);
      });
      final authService = AuthService(client: client);
      final provider = AuthProvider(authService: authService, secureStorage: mockStorage);
      
      await provider.login('shop@test.com', 'password');
      expect(provider.state, AuthState.authenticated);
      expect(await mockStorage.getToken(), 'fake_token');
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
