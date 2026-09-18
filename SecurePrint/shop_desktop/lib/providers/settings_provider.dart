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
      if (envStr == Environment.production.name) {
        AppConfig.currentEnvironment = Environment.production;
      } else if (envStr == Environment.lanTesting.name) {
        AppConfig.currentEnvironment = Environment.lanTesting;
      } else {
        AppConfig.currentEnvironment = Environment.development;
      }
    }

    final url = await _secureStorage.getBackendUrl();
    if (url != null && url.isNotEmpty) {
      AppConfig.customBackendUrl = url;
    }

    _isInitialized = true;
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
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'http://$formattedUrl';
    }

    AppConfig.customBackendUrl = formattedUrl;
    await _secureStorage.saveBackendUrl(formattedUrl);
    notifyListeners();
  }

  Future<void> toggleDetailedLogging(bool enable) async {
    AppConfig.enableDetailedLogging = enable;
    notifyListeners();
  }
}
