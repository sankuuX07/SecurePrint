enum Environment {
  development,
  lanTesting,
  production,
}

class AppConfig {
  static const String version = "1.0.0";
  static Environment currentEnvironment = Environment.development;

  static String get backendUrl {
    switch (currentEnvironment) {
      case Environment.development:
        return "http://127.0.0.1:8000";
      case Environment.lanTesting:
        // Replace with actual LAN IP when testing on LAN
        return "http://192.168.1.100:8000";
      case Environment.production:
        return "https://api.secureprint.example.com";
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

  // Example logging level placeholder
  static bool get enableDetailedLogging {
    return currentEnvironment != Environment.production;
  }
}
