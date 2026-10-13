/// Represents the supported duplex (sides) configuration for a print job.
enum PrintDuplexMode {
  simplex, // One-sided
  duplex;  // Two-sided (flip on long edge)

  /// Parses a backend / UI string (e.g. 'SINGLE', 'DOUBLE', 'SIMPLEX', 'DUPLEX')
  /// into a [PrintDuplexMode].
  ///
  /// Defaults to [PrintDuplexMode.simplex] if null or empty.
  /// Throws [UnsupportedPrinterSettingException] if the value is unrecognized.
  static PrintDuplexMode fromJobString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return PrintDuplexMode.simplex;
    }
    final normalized = value.trim().toUpperCase();
    switch (normalized) {
      case 'SINGLE':
      case 'SIMPLEX':
      case 'ONE_SIDED':
      case '1':
        return PrintDuplexMode.simplex;
      case 'DOUBLE':
      case 'DUPLEX':
      case 'TWO_SIDED':
      case '2':
        return PrintDuplexMode.duplex;
      default:
        throw UnsupportedPrinterSettingException(
          "Unrecognized print side setting: '$value'. Expected 'SINGLE' or 'DOUBLE'.",
        );
    }
  }
}

/// Represents the color mode configuration for a print job.
enum PrintColorMode {
  color,      // Full color
  monochrome; // Grayscale / Black & White

  /// Parses a backend / UI string (e.g. 'COLOR', 'BW', 'B/W', 'MONOCHROME', 'GRAYSCALE')
  /// into a [PrintColorMode].
  ///
  /// Defaults to [PrintColorMode.color] if null or empty.
  /// Throws [UnsupportedPrinterSettingException] if the value is unrecognized.
  static PrintColorMode fromJobString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return PrintColorMode.color;
    }
    final normalized = value.trim().toUpperCase().replaceAll('/', '').replaceAll(' ', '_');
    switch (normalized) {
      case 'COLOR':
      case 'COLOUR':
        return PrintColorMode.color;
      case 'BW':
      case 'B_W':
      case 'BLACK_AND_WHITE':
      case 'BLACK_WHITE':
      case 'MONOCHROME':
      case 'GRAYSCALE':
      case 'GREYSCALE':
        return PrintColorMode.monochrome;
      default:
        throw UnsupportedPrinterSettingException(
          "Unrecognized color mode setting: '$value'. Expected 'COLOR' or 'BW'.",
        );
    }
  }
}

/// Hardware capabilities of a detected printer.
class PrinterCapabilities {
  final bool supportsDuplex;
  final bool supportsColor;

  const PrinterCapabilities({
    required this.supportsDuplex,
    required this.supportsColor,
  });

  @override
  String toString() =>
      'PrinterCapabilities(supportsDuplex: $supportsDuplex, supportsColor: $supportsColor)';
}

/// Result returned after validating and applying printer settings.
class PrinterSettingsApplicationResult {
  final bool applied;
  final bool duplexApplied;
  final bool colorApplied;
  final String? message;

  const PrinterSettingsApplicationResult({
    required this.applied,
    required this.duplexApplied,
    required this.colorApplied,
    this.message,
  });

  @override
  String toString() =>
      'PrinterSettingsApplicationResult(applied: $applied, duplexApplied: $duplexApplied, colorApplied: $colorApplied)';
}

/// Exception thrown when a requested print setting (duplex or color) is
/// unsupported by the selected printer hardware or driver.
class UnsupportedPrinterSettingException implements Exception {
  final String message;
  const UnsupportedPrinterSettingException(this.message);

  @override
  String toString() => 'UnsupportedPrinterSettingException: $message';
}
