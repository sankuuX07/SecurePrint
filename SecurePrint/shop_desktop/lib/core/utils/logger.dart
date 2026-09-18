import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class Logger {
  static void info(String message) {
    if (!AppConfig.enableDetailedLogging) return;
    _printLog('INFO', message);
  }

  static void warning(String message) {
    if (!AppConfig.enableDetailedLogging) return;
    _printLog('WARN', message);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _printLog('ERROR', message);
    if (error != null) {
      _printLog('ERROR_DETAILS', error.toString());
    }
    if (stackTrace != null && AppConfig.enableDetailedLogging) {
      _printLog('STACKTRACE', stackTrace.toString());
    }
  }

  static void _printLog(String level, String message) {
    if (kDebugMode || AppConfig.enableDetailedLogging) {
      final redactedMessage = _redactSensitiveInfo(message);
      print('[$level] ${DateTime.now().toIso8601String()}: $redactedMessage');
    }
  }

  static String _redactSensitiveInfo(String text) {
    // Redact JWT Bearer tokens
    var redacted = text.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*'), 'Bearer [REDACTED]');
    // Note: Can add more redactions here (e.g. passwords, secure access tokens) if they accidentally appear in logs
    redacted = redacted.replaceAll(RegExp(r'"password"\s*:\s*"[^"]+"'), '"password": "[REDACTED]"');
    return redacted;
  }
}
