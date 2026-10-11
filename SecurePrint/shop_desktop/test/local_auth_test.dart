import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_desktop/core/config/app_config.dart';
import 'package:shop_desktop/core/security/pbkdf2_helper.dart';
import 'package:shop_desktop/services/auth_service.dart';
import 'package:shop_desktop/services/auth_service_interface.dart';
import 'package:shop_desktop/services/local_auth_service.dart';
import 'package:shop_desktop/services/secure_storage.dart';
import 'package:shop_desktop/providers/auth_provider.dart';

class InMemorySecureStorage extends SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> saveToken(String token) async {
    _store['token'] = token;
  }

  @override
  Future<String?> getToken() async {
    return _store['token'];
  }

  @override
  Future<void> deleteToken() async {
    _store.remove('token');
  }

  @override
  Future<void> saveRememberSession(bool remember) async {
    _store['remember_session'] = remember ? 'true' : 'false';
  }

  @override
  Future<bool> getRememberSession() async {
    return _store['remember_session'] == 'true';
  }

  @override
  Future<void> deleteRememberSession() async {
    _store.remove('remember_session');
  }

  @override
  Future<void> saveRememberedEmail(String email) async {
    _store['email'] = email;
  }

  @override
  Future<String?> getRememberedEmail() async {
    return _store['email'];
  }

  @override
  Future<void> deleteRememberedEmail() async {
    _store.remove('email');
  }

  @override
  Future<void> saveLocalUserData(String jsonStr) async {
    _store['local_user'] = jsonStr;
  }

  @override
  Future<String?> getLocalUserData() async {
    return _store['local_user'];
  }

  @override
  Future<void> deleteLocalUserData() async {
    _store.remove('local_user');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File localAccountsFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('secureprint_auth_test_');
    localAccountsFile = File('${tempDir.path}/test_local_accounts.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Pbkdf2Helper Cryptographic Tests', () {
    test('Hashes password using salted PBKDF2-HMAC-SHA256', () {
      final hash = Pbkdf2Helper.hashPassword('SuperSecret123!');
      expect(hash.startsWith('pbkdf2_sha256\$100000\$'), isTrue);
      final parts = hash.split('\$');
      expect(parts.length, 4);
    });

    test('Two hashes of the same password produce distinct salts and ciphertexts', () {
      final hash1 = Pbkdf2Helper.hashPassword('SamePassword123');
      final hash2 = Pbkdf2Helper.hashPassword('SamePassword123');
      expect(hash1, isNot(equals(hash2)));
    });

    test('Verifies correct password succeeds', () {
      final hash = Pbkdf2Helper.hashPassword('CorrectPassword123!');
      expect(Pbkdf2Helper.verifyPassword('CorrectPassword123!', hash), isTrue);
    });

    test('Verifies incorrect password fails', () {
      final hash = Pbkdf2Helper.hashPassword('CorrectPassword123!');
      expect(Pbkdf2Helper.verifyPassword('WrongPassword!', hash), isFalse);
    });

    test('Malformed hash returns false safely', () {
      expect(Pbkdf2Helper.verifyPassword('Password', 'invalid_hash_string'), isFalse);
      expect(Pbkdf2Helper.verifyPassword('Password', 'pbkdf2_sha256\$notanumber\$salt\$hash'), isFalse);
    });
  });

  group('LocalAuthService Tests', () {
    test('Register new account persists to file with hashed password', () async {
      final service = LocalAuthService(storageFile: localAccountsFile);
      final regData = ShopRegistrationData(
        ownerName: 'Alice Smith',
        shopName: 'Alice Print Corner',
        email: 'alice@shop.com',
        phone: '1234567890',
        password: 'Password123!',
        address: '100 Main St',
        city: 'Metro City',
      );

      await service.register(regData);

      expect(await localAccountsFile.exists(), isTrue);
      final content = await localAccountsFile.readAsString();
      final decoded = jsonDecode(content);

      // Verify no plaintext password exists
      expect(content.contains('Password123!'), isFalse);
      expect(decoded['users'], isNotEmpty);

      final user = decoded['users'][0];
      expect(user['name'], 'Alice Smith');
      expect(user['email'], 'alice@shop.com');
      expect(user['password_hash'].toString().startsWith('pbkdf2_sha256\$'), isTrue);
    });

    test('Duplicate email registration is rejected', () async {
      final service = LocalAuthService(storageFile: localAccountsFile);
      final regData = ShopRegistrationData(
        ownerName: 'Bob',
        shopName: 'Bob Prints',
        email: 'bob@shop.com',
        phone: '1234567890',
        password: 'Password123!',
        address: '100 Main St',
        city: 'Metro City',
      );

      await service.register(regData);

      // Attempt duplicate with uppercase variations
      final duplicateData = ShopRegistrationData(
        ownerName: 'Bob Duplicate',
        shopName: 'Bob Prints 2',
        email: 'BOB@shop.com',
        phone: '9876543210',
        password: 'DifferentPass123!',
        address: '200 Main St',
        city: 'Metro City',
      );

      expect(
        () => service.register(duplicateData),
        throwsA(isA<AuthServiceException>().having(
          (e) => e.message,
          'message',
          contains('already exists'),
        )),
      );
    });

    test('Correct credentials sign in and return local AuthResult', () async {
      final service = LocalAuthService(storageFile: localAccountsFile);
      await service.register(ShopRegistrationData(
        ownerName: 'Carol',
        shopName: 'Carol Xerox',
        email: 'carol@shop.com',
        phone: '1234567890',
        password: 'MySecurePassword99!',
        address: '300 Broadway',
        city: 'Gotham',
      ));

      final result = await service.login('carol@shop.com', 'MySecurePassword99!');
      expect(result.isLocal, isTrue);
      expect(result.role, 'SHOP');
      expect(result.token.startsWith('local_dev_'), isTrue);
      expect(result.user?.name, 'Carol');
      expect(result.user?.shopName, 'Carol Xerox');
    });

    test('Incorrect password is rejected with generic message', () async {
      final service = LocalAuthService(storageFile: localAccountsFile);
      await service.register(ShopRegistrationData(
        ownerName: 'Carol',
        shopName: 'Carol Xerox',
        email: 'carol@shop.com',
        phone: '1234567890',
        password: 'MySecurePassword99!',
        address: '300 Broadway',
        city: 'Gotham',
      ));

      expect(
        () => service.login('carol@shop.com', 'WrongPassword!'),
        throwsA(isA<AuthServiceException>().having(
          (e) => e.message,
          'message',
          contains('Incorrect email or password'),
        )),
      );
    });

    test('Unknown email is rejected with generic message', () async {
      final service = LocalAuthService(storageFile: localAccountsFile);
      expect(
        () => service.login('unknown@shop.com', 'AnyPassword!'),
        throwsA(isA<AuthServiceException>().having(
          (e) => e.message,
          'message',
          contains('Incorrect email or password'),
        )),
      );
    });

    test('Corrupted account file does not crash and handles safely', () async {
      await localAccountsFile.writeAsString('CORRUPTED_JSON_DATA{{{');
      final service = LocalAuthService(storageFile: localAccountsFile);

      // Attempting to login on corrupted file safely reports unknown user / reset
      expect(
        () => service.login('user@shop.com', 'pass'),
        throwsA(isA<AuthServiceException>()),
      );
    });
  });

  group('AuthProvider with Local Authentication Integration Tests', () {
    late InMemorySecureStorage mockStorage;
    late LocalAuthService localAuthService;

    setUp(() {
      AppConfig.authMode = AuthenticationMode.localDevelopment;
      mockStorage = InMemorySecureStorage();
      localAuthService = LocalAuthService(storageFile: localAccountsFile);
    });

    test('Local account registration and login via AuthProvider', () async {
      final provider = AuthProvider(
        localAuthService: localAuthService,
        secureStorage: mockStorage,
      );

      // Register local test account
      await provider.register(ShopRegistrationData(
        ownerName: 'Dave Owner',
        shopName: 'Dave Printing Hub',
        email: 'dave@shop.local',
        phone: '1234567890',
        password: 'Password123!',
        address: '123 Test Ave',
        city: 'Testville',
      ));

      // Login
      await provider.login(
        'dave@shop.local',
        'Password123!',
        rememberSession: false,
        rememberEmail: true,
      );

      expect(provider.isAuthenticated, isTrue);
      expect(provider.isLocalSession, isTrue);
      expect(provider.currentUser?.shopName, 'Dave Printing Hub');
      expect(await mockStorage.getRememberedEmail(), 'dave@shop.local');

      // Since rememberSession was false, token was NOT saved to storage
      expect(await mockStorage.getToken(), isNull);
    });

    test('Safe session persistence: token saved when rememberSession is true', () async {
      final provider = AuthProvider(
        localAuthService: localAuthService,
        secureStorage: mockStorage,
      );

      await provider.register(ShopRegistrationData(
        ownerName: 'Eve Owner',
        shopName: 'Eve Prints',
        email: 'eve@shop.local',
        phone: '1234567890',
        password: 'Password123!',
        address: '456 Test Blvd',
        city: 'Testville',
      ));

      await provider.login(
        'eve@shop.local',
        'Password123!',
        rememberSession: true,
      );

      expect(provider.isAuthenticated, isTrue);
      expect(await mockStorage.getToken(), isNotNull);

      // Simulated app restart with saved token restores session
      final restoredProvider = AuthProvider(
        localAuthService: localAuthService,
        secureStorage: mockStorage,
      );
      await Future.delayed(Duration.zero);
      expect(restoredProvider.isAuthenticated, isTrue);
      expect(restoredProvider.isLocalSession, isTrue);
      expect(restoredProvider.currentUser?.shopName, 'Eve Prints');
    });

    test('Logout clears active session and stored credentials', () async {
      final provider = AuthProvider(
        localAuthService: localAuthService,
        secureStorage: mockStorage,
      );

      await provider.register(ShopRegistrationData(
        ownerName: 'Frank',
        shopName: 'Frank Copy Center',
        email: 'frank@shop.local',
        phone: '1234567890',
        password: 'Password123!',
        address: '789 Elm St',
        city: 'Springfield',
      ));

      await provider.login(
        'frank@shop.local',
        'Password123!',
        rememberSession: true,
      );
      expect(provider.isAuthenticated, isTrue);

      await provider.logout();
      expect(provider.isAuthenticated, isFalse);
      expect(provider.isLocalSession, isFalse);
      expect(provider.currentUser, isNull);
      expect(await mockStorage.getToken(), isNull);
    });

    test('Local authentication does not make backend network calls or report server errors', () async {
      final provider = AuthProvider(
        localAuthService: localAuthService,
        secureStorage: mockStorage,
      );

      // Attempt login with non-existent local account
      await provider.login('notfound@shop.local', 'Password123!');
      expect(provider.isAuthenticated, isFalse);
      expect(provider.errorMessage, 'Incorrect email or password.');
      // Must NOT contain server connection error
      expect(provider.errorMessage, isNot(contains('Unable to connect to SecurePrint server')));
    });
  });
}
