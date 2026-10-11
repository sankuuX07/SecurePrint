enum Environment {
  development,
  lanTesting,
  production,
}

enum AuthenticationMode {
  localDevelopment,
  productionBackend,
}

class AppConfig {
  static const String version = "1.0.0";
  
  // These will be initialized by SettingsProvider on startup
  static Environment currentEnvironment = Environment.production;
  static AuthenticationMode authMode = AuthenticationMode.localDevelopment;
  static String? customBackendUrl;
  static bool enableDetailedLogging = false;

  static String get backendUrl {
    if (customBackendUrl != null && customBackendUrl!.isNotEmpty) {
      return customBackendUrl!;
    }

    switch (currentEnvironment) {
      case Environment.development:
        return "http://127.0.0.1:8000";
      case Environment.lanTesting:
        return "http://192.168.1.100:8000";
      case Environment.production:
        return ""; // Should be configured via UI
    }
  }

  static String get environmentName {
    switch (currentEnvironment) {
      case Environment.development:
        return "Development";
      case Environment.lanTesting:
        return "LAN Testing";
      case Environment.production:
        return "Production";
    }
  }

  static String get authModeName {
    switch (authMode) {
      case AuthenticationMode.localDevelopment:
        return "Local Development";
      case AuthenticationMode.productionBackend:
        return "Production Backend";
    }
  }
}
