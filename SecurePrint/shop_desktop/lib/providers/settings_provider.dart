import 'package:flutter/material.dart';
import '../services/secure_storage.dart';
import '../core/config/app_config.dart';

class SettingsProvider extends ChangeNotifier {
  final SecureStorage _secureStorage;
  bool _isInitialized = false;

  SettingsProvider({SecureStorage? secureStorage}) 
      : _secureStorage = secureStorage ?? SecureStorage();

  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    final envStr = await _secureStorage.getEnvironment();
    if (envStr != null) {
      if (envStr == Environment.development.name) {
        AppConfig.currentEnvironment = Environment.development;
      } else if (envStr == Environment.lanTesting.name) {
        AppConfig.currentEnvironment = Environment.lanTesting;
      } else if (envStr == Environment.production.name) {
        AppConfig.currentEnvironment = Environment.production;
      }
    } else {
        AppConfig.currentEnvironment = Environment.production;
    }

    final authModeStr = await _secureStorage.getAuthMode();
    if (authModeStr != null) {
      if (authModeStr == AuthenticationMode.productionBackend.name) {
        AppConfig.authMode = AuthenticationMode.productionBackend;
      } else {
        AppConfig.authMode = AuthenticationMode.localDevelopment;
      }
    } else {
      AppConfig.authMode = AuthenticationMode.localDevelopment;
    }

    final url = await _secureStorage.getBackendUrl();
    if (url != null && url.isNotEmpty) {
      AppConfig.customBackendUrl = url;
    } else {
      AppConfig.customBackendUrl = null;
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setAuthMode(AuthenticationMode mode) async {
    AppConfig.authMode = mode;
    await _secureStorage.saveAuthMode(mode.name);
    notifyListeners();
  }

  Future<void> setEnvironment(Environment env) async {
    AppConfig.currentEnvironment = env;
    await _secureStorage.saveEnvironment(env.name);
    
    // Clear custom URL if they switch environments to force using the new default
    // unless they explicitly re-set the custom URL
    AppConfig.customBackendUrl = null;
    await _secureStorage.saveBackendUrl('');
    
    notifyListeners();
  }

  Future<void> setBackendUrl(String url) async {
    // Basic formatting normalization
    String formattedUrl = url.trim();
    if (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://') && formattedUrl.isNotEmpty) {
      formattedUrl = 'http://$formattedUrl';
    }

    AppConfig.customBackendUrl = formattedUrl.isEmpty ? null : formattedUrl;
    await _secureStorage.saveBackendUrl(formattedUrl);
    notifyListeners();
  }

  Future<void> toggleDetailedLogging(bool enable) async {
    AppConfig.enableDetailedLogging = enable;
    notifyListeners();
  }
}
