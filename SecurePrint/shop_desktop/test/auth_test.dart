import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_desktop/core/config/app_config.dart';
import 'package:shop_desktop/core/networking/api_client.dart';
import 'package:shop_desktop/services/auth_service.dart';
import 'package:shop_desktop/services/backend_auth_service.dart';
import 'package:shop_desktop/services/local_auth_service.dart';
import 'package:shop_desktop/services/secure_storage.dart';
import 'package:shop_desktop/services/shop_service.dart';
import 'package:shop_desktop/providers/auth_provider.dart';
import 'package:shop_desktop/providers/dashboard_provider.dart';

class MockSecureStorage extends SecureStorage {
  String? _token;
  bool _rememberSession = false;

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

  @override
  Future<void> saveRememberSession(bool remember) async {
    _rememberSession = remember;
  }

  @override
  Future<bool> getRememberSession() async {
    return _rememberSession;
  }

  @override
  Future<void> deleteRememberSession() async {
    _rememberSession = false;
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

    test('Existing authenticated session restoration when rememberSession is true', () async {
      await mockStorage.saveToken('existing_token');
      await mockStorage.saveRememberSession(true);
      final provider = AuthProvider(secureStorage: mockStorage);
      // Wait a microtask for initialization to finish
      await Future.delayed(Duration.zero);
      expect(provider.state, AuthState.authenticated);
      expect(await mockStorage.getToken(), 'existing_token');
    });

    test('Session is not restored on restart when rememberSession is false', () async {
      await mockStorage.saveToken('existing_token');
      await mockStorage.saveRememberSession(false);
      final provider = AuthProvider(secureStorage: mockStorage);
      await Future.delayed(Duration.zero);
      expect(provider.state, AuthState.unauthenticated);
      expect(await mockStorage.getToken(), isNull);
    });

    test('Login with rememberSession: false keeps token available for active session', () async {
      final client = MockClient((request) async {
        return http.Response(
            jsonEncode({'access_token': 'active_token_123', 'role': 'SHOP'}), 200);
      });
      final authService = AuthService(client: client);
      final provider = AuthProvider(authService: authService, secureStorage: mockStorage);

      await provider.login('shop@test.com', 'password', rememberSession: false);

      expect(provider.state, AuthState.authenticated);
      expect(provider.isAuthenticated, isTrue);
      // Token must be available for ApiClient during active session
      expect(await mockStorage.getToken(), 'active_token_123');
      expect(await mockStorage.getRememberSession(), isFalse);

      // But upon app restart, session is not restored
      final restartedProvider = AuthProvider(authService: authService, secureStorage: mockStorage);
      await Future.delayed(Duration.zero);
      expect(restartedProvider.state, AuthState.unauthenticated);
      expect(await mockStorage.getToken(), isNull);
    });

    test('Login with rememberSession: true persists token and restores session on restart', () async {
      final client = MockClient((request) async {
        return http.Response(
            jsonEncode({'access_token': 'persisted_token_456', 'role': 'SHOP'}), 200);
      });
      final authService = AuthService(client: client);
      final provider = AuthProvider(authService: authService, secureStorage: mockStorage);

      await provider.login('shop@test.com', 'password', rememberSession: true);

      expect(provider.state, AuthState.authenticated);
      expect(await mockStorage.getToken(), 'persisted_token_456');
      expect(await mockStorage.getRememberSession(), isTrue);

      // Upon app restart, session is restored
      final restartedProvider = AuthProvider(authService: authService, secureStorage: mockStorage);
      await Future.delayed(Duration.zero);
      expect(restartedProvider.state, AuthState.authenticated);
      expect(await mockStorage.getToken(), 'persisted_token_456');
    });

    test('Unchecked rememberSession allows ApiClient to authenticate /api/v1/users/me and load dashboard', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/auth/login')) {
          return http.Response(
              jsonEncode({'access_token': 'bearer_jwt_token', 'role': 'SHOP'}), 200);
        } else if (request.url.path.contains('/users/me')) {
          // Verify that Authorization header is present with Bearer token!
          final authHeader = request.headers['Authorization'];
          if (authHeader == 'Bearer bearer_jwt_token') {
            return http.Response(
              jsonEncode({
                'id': 10,
                'name': 'Shop Owner',
                'email': 'shop@test.com',
                'phone': '1234567890',
                'role': 'SHOP',
                'shop_name': 'Approved Shop',
                'address': '123 Main St',
                'city': 'Metropolis',
              }),
              200,
            );
          } else {
            return http.Response(jsonEncode({'detail': 'Not authenticated'}), 401);
          }
        } else if (request.url.path.contains('/print-jobs/shop')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('Not Found', 404);
      });

      final authService = AuthService(client: client);
      final authProvider = AuthProvider(authService: authService, secureStorage: mockStorage);

      // User logs in with rememberSession == false (default UI state)
      await authProvider.login('shop@test.com', 'password', rememberSession: false);
      expect(authProvider.isAuthenticated, isTrue);

      // ApiClient and DashboardProvider query /api/v1/users/me using the same storage
      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final dashboardProvider = DashboardProvider(shopService: shopService);

      await dashboardProvider.loadDashboard();

      // Dashboard must be loaded and NOT unauthorized (preventing login flickering)
      expect(dashboardProvider.state, DashboardState.loaded);
      expect(dashboardProvider.shopProfile?.shopName, 'Approved Shop');
      expect(dashboardProvider.errorMessage, isNull);
    });
  });
}
