import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:shop_desktop/providers/printer_provider.dart';
import 'package:shop_desktop/services/printer_service.dart';
import 'package:shop_desktop/services/secure_storage.dart';

class MockPrinterService extends PrinterService {
  final List<Printer> mockPrinters;
  final Printer? mockDefault;
  final bool shouldThrow;

  MockPrinterService({
    this.mockPrinters = const [],
    this.mockDefault,
    this.shouldThrow = false,
  });

  @override
  Future<List<Printer>> getPrinters() async {
    if (shouldThrow) throw Exception('API Error');
    return mockPrinters;
  }

  @override
  Future<Printer?> getDefaultPrinter() async {
    return mockDefault;
  }
}

class MockSecureStorage extends SecureStorage {
  String? preferred;

  @override
  Future<void> savePreferredPrinter(String printerName) async {
    preferred = printerName;
  }

  @override
  Future<String?> getPreferredPrinter() async {
    return preferred;
  }
}

void main() {
  group('PrinterProvider Tests', () {
    test('loadPrinters selects default printer when no preferred is set', () async {
      final mockPrinters = [
        const Printer(name: 'Printer A', url: 'url1', model: 'A', isDefault: false, isAvailable: true),
        const Printer(name: 'Printer B', url: 'url2', model: 'B', isDefault: true, isAvailable: true),
      ];
      
      final service = MockPrinterService(mockPrinters: mockPrinters, mockDefault: mockPrinters[1]);
      final storage = MockSecureStorage();
      final provider = PrinterProvider(printerService: service, secureStorage: storage);

      await provider.loadPrinters();

      expect(provider.printers.length, 2);
      expect(provider.selectedPrinter?.name, 'Printer B');
      expect(provider.errorMessage, isNull);
    });

    test('loadPrinters selects preferred printer over default if it exists', () async {
      final mockPrinters = [
        const Printer(name: 'Printer A', url: 'url1', model: 'A', isDefault: false, isAvailable: true),
        const Printer(name: 'Printer B', url: 'url2', model: 'B', isDefault: true, isAvailable: true),
      ];
      
      final service = MockPrinterService(mockPrinters: mockPrinters, mockDefault: mockPrinters[1]);
      final storage = MockSecureStorage()..preferred = 'Printer A';
      final provider = PrinterProvider(printerService: service, secureStorage: storage);

      await provider.loadPrinters();

      expect(provider.selectedPrinter?.name, 'Printer A');
    });

    test('loadPrinters falls back to first printer if default and preferred are missing', () async {
      final mockPrinters = [
        const Printer(name: 'Printer A', url: 'url1', model: 'A', isDefault: false, isAvailable: true),
        const Printer(name: 'Printer B', url: 'url2', model: 'B', isDefault: false, isAvailable: true),
      ];
      
      final service = MockPrinterService(mockPrinters: mockPrinters, mockDefault: null);
      final storage = MockSecureStorage();
      final provider = PrinterProvider(printerService: service, secureStorage: storage);

      await provider.loadPrinters();

      expect(provider.selectedPrinter?.name, 'Printer A');
    });

    test('loadPrinters handles empty printer list', () async {
      final service = MockPrinterService(mockPrinters: []);
      final storage = MockSecureStorage();
      final provider = PrinterProvider(printerService: service, secureStorage: storage);

      await provider.loadPrinters();

      expect(provider.printers, isEmpty);
      expect(provider.selectedPrinter, isNull);
      expect(provider.errorMessage, 'No printers were found.');
    });

    test('loadPrinters handles exceptions', () async {
      final service = MockPrinterService(shouldThrow: true);
      final storage = MockSecureStorage();
      final provider = PrinterProvider(printerService: service, secureStorage: storage);

      await provider.loadPrinters();

      expect(provider.printers, isEmpty);
      expect(provider.selectedPrinter, isNull);
      expect(provider.errorMessage, 'Unable to detect Windows printers.');
    });

    test('selectPrinter saves preference', () async {
      final storage = MockSecureStorage();
      final provider = PrinterProvider(printerService: MockPrinterService(), secureStorage: storage);

      final printer = const Printer(name: 'Target Printer', url: 'url', model: 'model', isDefault: false, isAvailable: true);
      await provider.selectPrinter(printer);

      expect(provider.selectedPrinter, printer);
      expect(storage.preferred, 'Target Printer');
    });
  });
}
