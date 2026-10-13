import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import '../services/printer_service.dart';
import '../services/secure_storage.dart';
import '../models/print_settings.dart';
import '../services/printer_settings_service.dart';

class PrinterProvider extends ChangeNotifier {
  final PrinterService _printerService;
  final SecureStorage _secureStorage;
  final PrinterSettingsService _printerSettingsService;

  List<Printer> _printers = [];
  List<Printer> get printers => _printers;

  Printer? _selectedPrinter;
  Printer? get selectedPrinter => _selectedPrinter;

  PrinterCapabilities? _selectedPrinterCapabilities;
  PrinterCapabilities? get selectedPrinterCapabilities => _selectedPrinterCapabilities;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  PrinterProvider({
    PrinterService? printerService,
    SecureStorage? secureStorage,
    PrinterSettingsService? printerSettingsService,
  })  : _printerService = printerService ?? PrinterService(),
        _secureStorage = secureStorage ?? SecureStorage(),
        _printerSettingsService = printerSettingsService ?? WindowsPrinterSettingsService();

  Future<void> loadPrinters() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _printers = await _printerService.getPrinters();
      
      if (_printers.isEmpty) {
        _errorMessage = 'No printers were found.';
        _selectedPrinter = null;
        _selectedPrinterCapabilities = null;
      } else {
        // Attempt to select the preferred printer first
        final preferredPrinterName = await _secureStorage.getPreferredPrinter();
        if (preferredPrinterName != null) {
          try {
            _selectedPrinter = _printers.firstWhere((p) => p.name == preferredPrinterName);
          } catch (_) {
            _selectedPrinter = null; // Preferred printer no longer exists
          }
        }

        // Fallback to Windows default printer if no preferred printer is selected
        if (_selectedPrinter == null) {
          final defaultPrinter = await _printerService.getDefaultPrinter();
          if (defaultPrinter != null) {
            _selectedPrinter = defaultPrinter;
          } else {
            // Ultimate fallback
            _selectedPrinter = _printers.first;
          }
        }

        if (_selectedPrinter != null) {
          try {
            _selectedPrinterCapabilities =
                await _printerSettingsService.getCapabilities(_selectedPrinter!.name);
          } catch (_) {
            _selectedPrinterCapabilities = null;
          }
        }
      }
    } catch (e) {
      _errorMessage = 'Unable to detect Windows printers.';
      _printers = [];
      _selectedPrinter = null;
      _selectedPrinterCapabilities = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectPrinter(Printer printer) async {
    _selectedPrinter = printer;
    await _secureStorage.savePreferredPrinter(printer.name);
    try {
      _selectedPrinterCapabilities =
          await _printerSettingsService.getCapabilities(printer.name);
    } catch (_) {
      _selectedPrinterCapabilities = null;
    }
    notifyListeners();
  }
}
