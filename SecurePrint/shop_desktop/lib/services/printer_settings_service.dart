import 'package:flutter/services.dart';
import '../models/print_settings.dart';

/// Abstract contract for printer settings inspection and application.
abstract class PrinterSettingsService {
  /// Queries hardware/driver capabilities for [printerName].
  Future<PrinterCapabilities> getCapabilities(String printerName);

  /// Validates and applies [duplexMode] and [colorMode] to the specified printer.
  ///
  /// Throws [UnsupportedPrinterSettingException] if the requested setting
  /// is unsupported or rejected by the driver.
  Future<PrinterSettingsApplicationResult> applySettings(
    String printerName, {
    required PrintDuplexMode duplexMode,
    required PrintColorMode colorMode,
  });
}

/// Windows implementation backed by the native runner MethodChannel
/// ('secureprint/printer_settings').
class WindowsPrinterSettingsService implements PrinterSettingsService {
  final MethodChannel _channel;

  WindowsPrinterSettingsService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('secureprint/printer_settings');

  @override
  Future<PrinterCapabilities> getCapabilities(String printerName) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getPrinterCapabilities',
        {'printerName': printerName},
      );

      return PrinterCapabilities(
        supportsDuplex: result?['supportsDuplex'] as bool? ?? false,
        supportsColor: result?['supportsColor'] as bool? ?? false,
      );
    } on PlatformException catch (e) {
      throw UnsupportedPrinterSettingException(
        e.message ?? 'Failed to retrieve capabilities for printer "$printerName".',
      );
    }
  }

  @override
  Future<PrinterSettingsApplicationResult> applySettings(
    String printerName, {
    required PrintDuplexMode duplexMode,
    required PrintColorMode colorMode,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'applyPrinterSettings',
        {
          'printerName': printerName,
          'duplex': duplexMode.name,
          'colorMode': colorMode.name,
        },
      );

      return PrinterSettingsApplicationResult(
        applied: result?['applied'] as bool? ?? true,
        duplexApplied: result?['duplexApplied'] as bool? ?? (duplexMode == PrintDuplexMode.duplex),
        colorApplied: result?['colorApplied'] as bool? ?? (colorMode == PrintColorMode.color),
      );
    } on PlatformException catch (e) {
      throw UnsupportedPrinterSettingException(
        e.message ?? 'Failed to apply settings to printer "$printerName".',
      );
    }
  }
}
