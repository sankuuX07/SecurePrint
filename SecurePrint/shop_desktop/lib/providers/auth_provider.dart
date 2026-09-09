import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/secure_storage.dart';

enum AuthState {
  uninitialized,
  unauthenticated,
  loggingIn,
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final SecureStorage _secureStorage;

  AuthState _state = AuthState.uninitialized;
  String? _errorMessage;

  AuthProvider({AuthService? authService, SecureStorage? secureStorage})
      : _authService = authService ?? AuthService(),
        _secureStorage = secureStorage ?? SecureStorage() {
    _initialize();
  }

  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;

  Future<void> _initialize() async {
    final token = await _secureStorage.getToken();
    if (token != null) {
      // In a full implementation, we might validate the token with the backend here
      _state = AuthState.authenticated;
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      _errorMessage = 'Please enter your email and password.';
      notifyListeners();
      return;
    }

    _state = AuthState.loggingIn;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _authService.login(email, password);
      await _secureStorage.saveToken(token);
      _state = AuthState.authenticated;
    } catch (e) {
      _state = AuthState.unauthenticated;
      _errorMessage = e.toString();
    }
    
    notifyListeners();
  }

  Future<void> logout() async {
    await _secureStorage.deleteToken();
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
