import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/auth_service_interface.dart';
import '../services/backend_auth_service.dart';
import '../services/local_auth_service.dart';
import '../services/secure_storage.dart';

enum AuthState {
  uninitialized,
  unauthenticated,
  loggingIn,
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  final SecureStorage _secureStorage;
  final IAuthService? _customAuthService;
  final LocalAuthService _localAuthService;
  final BackendAuthService _backendAuthService;

  AuthState _state = AuthState.uninitialized;
  String? _errorMessage;
  bool _isLocalSession = false;
  UserModel? _currentUser;

  AuthProvider({
    dynamic authService,
    SecureStorage? secureStorage,
    LocalAuthService? localAuthService,
    BackendAuthService? backendAuthService,
  })  : _secureStorage = secureStorage ?? SecureStorage(),
        _localAuthService = localAuthService ?? LocalAuthService(),
        _backendAuthService = backendAuthService ?? BackendAuthService(),
        _customAuthService = _resolveCustomAuthService(authService) {
    _initialize();
  }

  static IAuthService? _resolveCustomAuthService(dynamic authService) {
    if (authService == null) return null;
    if (authService is IAuthService) return authService;
    if (authService is AuthService) return BackendAuthService(authService: authService);
    return null;
  }

  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLocalSession => _isLocalSession;
  UserModel? get currentUser => _currentUser;

  IAuthService get activeAuthService => _getService();

  IAuthService _getService() {
    if (_customAuthService != null) {
      return _customAuthService;
    }
    if (AppConfig.authMode == AuthenticationMode.localDevelopment) {
      return _localAuthService;
    }
    return _backendAuthService;
  }

  Future<void> _initialize() async {
    final token = await _secureStorage.getToken();
    if (token != null) {
      final localDataStr = await _secureStorage.getLocalUserData();
      if (localDataStr != null) {
        try {
          final decoded = jsonDecode(localDataStr);
          if (decoded is Map<String, dynamic>) {
            _currentUser = UserModel.fromJson(decoded);
            _isLocalSession = true;
          }
        } catch (_) {}
      } else {
        _isLocalSession = false;
      }
      _state = AuthState.authenticated;
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login(
    String email,
    String password, {
    bool rememberSession = true,
    bool rememberEmail = false,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      _errorMessage = 'Please enter your email and password.';
      notifyListeners();
      return;
    }

    _state = AuthState.loggingIn;
    _errorMessage = null;
    notifyListeners();

    try {
      final service = _getService();
      final result = await service.login(trimmedEmail, password);

      if (rememberEmail) {
        await _secureStorage.saveRememberedEmail(trimmedEmail);
      } else {
        await _secureStorage.deleteRememberedEmail();
      }

      _isLocalSession = result.isLocal;
      _currentUser = result.user;

      if (rememberSession) {
        await _secureStorage.saveToken(result.token);
        await _secureStorage.saveRememberSession(true);
        if (result.isLocal && result.user != null) {
          await _secureStorage.saveLocalUserData(jsonEncode(result.user!.toJson()));
        }
      } else {
        await _secureStorage.deleteToken();
        await _secureStorage.deleteRememberSession();
        await _secureStorage.deleteLocalUserData();
      }

      _state = AuthState.authenticated;
    } catch (e) {
      _state = AuthState.unauthenticated;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  Future<void> register(ShopRegistrationData data) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final service = _getService();
      await service.register(data);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    await _secureStorage.deleteToken();
    await _secureStorage.deleteRememberSession();
    await _secureStorage.deleteLocalUserData();
    _isLocalSession = false;
    _currentUser = null;
    _state = AuthState.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
