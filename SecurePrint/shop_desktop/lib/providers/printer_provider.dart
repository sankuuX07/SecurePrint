import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import '../services/printer_service.dart';
import '../services/secure_storage.dart';

class PrinterProvider extends ChangeNotifier {
  final PrinterService _printerService;
  final SecureStorage _secureStorage;

  List<Printer> _printers = [];
  List<Printer> get printers => _printers;

  Printer? _selectedPrinter;
  Printer? get selectedPrinter => _selectedPrinter;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  PrinterProvider({
    PrinterService? printerService,
    SecureStorage? secureStorage,
  })  : _printerService = printerService ?? PrinterService(),
        _secureStorage = secureStorage ?? SecureStorage();

  Future<void> loadPrinters() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _printers = await _printerService.getPrinters();
      
      if (_printers.isEmpty) {
        _errorMessage = 'No printers were found.';
        _selectedPrinter = null;
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
      }
    } catch (e) {
      _errorMessage = 'Unable to detect Windows printers.';
      _printers = [];
      _selectedPrinter = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectPrinter(Printer printer) async {
    _selectedPrinter = printer;
    await _secureStorage.savePreferredPrinter(printer.name);
    notifyListeners();
  }
}
