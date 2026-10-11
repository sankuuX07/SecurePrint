import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/security/pbkdf2_helper.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'auth_service_interface.dart';

/// Isolated, development-only local authentication service.
/// Persists test accounts in the user's application-data directory
/// using salted PBKDF2-HMAC-SHA256 password hashing.
class LocalAuthService implements IAuthService {
  final File? _customStorageFile;
  File? _resolvedStorageFile;

  LocalAuthService({File? storageFile}) : _customStorageFile = storageFile;

  /// Resolves the file location within the user's application data directory.
  Future<File> _getStorageFile() async {
    if (_customStorageFile != null) {
      return _customStorageFile;
    }
    if (_resolvedStorageFile != null) {
      return _resolvedStorageFile!;
    }

    String baseDir;
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      baseDir = appSupportDir.path;
    } catch (_) {
      // Fallback for environments where path_provider channel is unmocked (e.g. unit tests)
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        baseDir = appData;
      } else {
        baseDir = p.join(Directory.systemTemp.path, 'SecurePrintShopAppData');
      }
    }

    final securePrintDir = Directory(p.join(baseDir, 'SecurePrintShop'));
    if (!await securePrintDir.exists()) {
      await securePrintDir.create(recursive: true);
    }

    _resolvedStorageFile = File(p.join(securePrintDir.path, 'local_accounts.json'));
    return _resolvedStorageFile!;
  }

  /// Reads accounts from local storage.
  /// Handles file creation and recovers safely from corrupted files.
  Future<List<Map<String, dynamic>>> _loadAccounts() async {
    try {
      final file = await _getStorageFile();
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return [];
      }

      final dynamic decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic> && decoded['users'] is List) {
        return List<Map<String, dynamic>>.from(decoded['users']);
      } else if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      } else {
        throw const FormatException('Unexpected schema in local accounts file');
      }
    } on FormatException {
      // Safely handle corrupted local account file without exposing paths
      await _handleCorruptedStore();
      return [];
    } catch (e) {
      if (e is AuthServiceException) rethrow;
      throw AuthServiceException('Failed to access local account storage.');
    }
  }

  /// Backs up corrupted file and resets storage safely.
  Future<void> _handleCorruptedStore() async {
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final backupName = 'local_accounts_corrupted_${DateTime.now().millisecondsSinceEpoch}.bak';
        final backupFile = File(p.join(file.parent.path, backupName));
        await file.rename(backupFile.path);
      }
    } catch (_) {}
  }

  /// Saves the accounts list atomically to local storage.
  Future<void> _saveAccounts(List<Map<String, dynamic>> accounts) async {
    try {
      final file = await _getStorageFile();
      final data = {
        'version': 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'users': accounts,
      };
      
      // Write to temp file first then rename for atomic replacement
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonEncode(data), flush: true);
      await tempFile.rename(file.path);
    } catch (e) {
      throw AuthServiceException('Failed to write to local account storage.');
    }
  }

  @override
  Future<AuthResult> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw AuthServiceException('Please enter your email and password.');
    }

    final accounts = await _loadAccounts();
    final account = accounts.firstWhere(
      (u) => (u['email'] as String? ?? '').toLowerCase() == normalizedEmail,
      orElse: () => {},
    );

    if (account.isEmpty) {
      throw AuthServiceException('Incorrect email or password.');
    }

    final storedHash = account['password_hash'] as String?;
    if (storedHash == null || !Pbkdf2Helper.verifyPassword(password, storedHash)) {
      throw AuthServiceException('Incorrect email or password.');
    }

    final role = account['role'] as String? ?? 'SHOP';
    if (role != 'SHOP') {
      throw AuthServiceException('Access Denied. Shop accounts only.');
    }

    // Generate local dev session token
    final randomBytes = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    final localToken = 'local_dev_${base64UrlEncode(randomBytes)}';

    final user = UserModel(
      id: account['id'] as int? ?? 1,
      name: account['name'] as String? ?? 'Shop Owner',
      email: account['email'] as String? ?? normalizedEmail,
      phone: account['phone'] as String? ?? '',
      role: role,
      shopName: account['shop_name'] as String? ?? 'Local Test Shop',
      address: account['address'] as String? ?? '',
      city: account['city'] as String? ?? '',
    );

    return AuthResult(
      token: localToken,
      role: role,
      user: user,
      isLocal: true,
    );
  }

  @override
  Future<void> register(ShopRegistrationData data) async {
    final normalizedEmail = data.email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw AuthServiceException('Email address is required.');
    }
    if (data.password.isEmpty) {
      throw AuthServiceException('Password is required.');
    }

    final accounts = await _loadAccounts();

    // Check for duplicate email
    final exists = accounts.any(
      (u) => (u['email'] as String? ?? '').toLowerCase() == normalizedEmail,
    );
    if (exists) {
      throw AuthServiceException('An account with this email address already exists.');
    }

    // Determine next local ID
    int maxId = 0;
    for (final u in accounts) {
      final id = u['id'] as int? ?? 0;
      if (id > maxId) maxId = id;
    }
    final nextId = maxId + 1;

    // Hash password using PBKDF2-HMAC-SHA256
    final passwordHash = Pbkdf2Helper.hashPassword(data.password);

    final newAccount = {
      'id': nextId,
      'name': data.ownerName.trim(),
      'shop_name': data.shopName.trim(),
      'email': normalizedEmail,
      'phone': data.phone.trim(),
      'address': data.address.trim(),
      'city': data.city.trim(),
      'password_hash': passwordHash,
      'role': 'SHOP',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    accounts.add(newAccount);
    await _saveAccounts(accounts);
  }
}
