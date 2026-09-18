import 'package:printing/printing.dart';

class PrinterService {
  /// Fetches a list of installed printers.
  Future<List<Printer>> getPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      // In case of an unexpected platform error retrieving printers
      throw Exception('Unable to detect Windows printers: $e');
    }
  }

  /// Attempts to find the default printer based on the isDefault flag.
  Future<Printer?> getDefaultPrinter() async {
    try {
      final printers = await getPrinters();
      for (var printer in printers) {
        if (printer.isDefault) {
          return printer;
        }
      }
      return null;
    } catch (e) {
      return null; // Safe fallback
    }
  }
}
