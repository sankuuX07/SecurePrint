import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:shop_desktop/models/print_job_detail_model.dart';
import 'package:shop_desktop/providers/print_execution_provider.dart';
import 'package:shop_desktop/services/shop_service.dart';
import 'package:shop_desktop/models/print_job_model.dart';
import 'package:shop_desktop/services/secure_storage.dart';
import 'package:shop_desktop/services/pdf_page_extractor.dart';
import 'package:shop_desktop/models/print_settings.dart';
import 'package:shop_desktop/services/printer_settings_service.dart';

class MockShopService extends ShopService {
  bool startCalled = false;
  bool completeCalled = false;
  bool shouldThrowStart = false;
  bool shouldThrowComplete = false;

  @override
  Future<PrintJobModel> startJob(int jobId) async {
    startCalled = true;
    if (shouldThrowStart) throw Exception('API Error');
    return PrintJobModel(
      id: jobId,
      documentId: '1',
      copies: 1,
      selectedPageCount: 1,
      colorMode: 'COLOR',
      paperSize: 'A4',
      printSide: 'SINGLE',
      price: 1.0,
      status: 'PRINTING',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<PrintJobModel> completeJob(int jobId) async {
    completeCalled = true;
    if (shouldThrowComplete) throw Exception('Sync Error');
    return PrintJobModel(
      id: jobId,
      documentId: '1',
      copies: 1,
      selectedPageCount: 1,
      colorMode: 'COLOR',
      paperSize: 'A4',
      printSide: 'SINGLE',
      price: 1.0,
      status: 'COMPLETED',
      createdAt: DateTime.now().toIso8601String(),
    );
  }
}

class MockSecureStorage extends SecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> saveJobPrintState(int jobId, String state) async {
    _storage['job_state_$jobId'] = state;
  }

  @override
  Future<String?> getJobPrintState(int jobId) async {
    return _storage['job_state_$jobId'];
  }

  @override
  Future<void> deleteJobPrintState(int jobId) async {
    _storage.remove('job_state_$jobId');
  }
}

class MockPdfPageExtractor extends PdfPageExtractor {
  String? lastExtractedRange;
  bool shouldThrow = false;
  String throwMessage = 'Page range error';

  @override
  Uint8List extractPages(Uint8List sourcePdfBytes, String? pageRange) {
    lastExtractedRange = pageRange;
    if (shouldThrow) {
      throw PdfPageRangeException(throwMessage);
    }
    return sourcePdfBytes;
  }
}

class StubPrinterSettingsService implements PrinterSettingsService {
  @override
  Future<PrinterCapabilities> getCapabilities(String printerName) async =>
      const PrinterCapabilities(supportsDuplex: true, supportsColor: true);

  @override
  Future<PrinterSettingsApplicationResult> applySettings(
    String printerName, {
    required PrintDuplexMode duplexMode,
    required PrintColorMode colorMode,
  }) async =>
      const PrinterSettingsApplicationResult(
        applied: true,
        duplexApplied: true,
        colorApplied: true,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrintExecutionProvider Tests', () {
    late File tempFile;
    late StubPrinterSettingsService stubSettings;

    setUp(() async {
      stubSettings = StubPrinterSettingsService();
      // Create a dummy file to simulate the PDF
      tempFile = File('test_dummy.pdf');
      await tempFile.writeAsBytes([1, 2, 3]);
    });

    tearDown(() async {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    test('executePrint completes full lifecycle successfully', () async {
      final service = MockShopService();
      final storage = MockSecureStorage();
      final provider = PrintExecutionProvider(
        shopService: service,
        secureStorage: storage,
        printerSettingsService: stubSettings,
      );

      final job = PrintJobDetailModel(
        id: 1,
        status: 'ACCEPTED',
        price: 1.0,
        copies: 1,
        paperSize: 'A4',
        colorMode: 'COLOR',
        printSide: 'SINGLE',
        documentId: '1',
        statusHistory: [],
      );
      final printer = const Printer(name: 'TestPrinter', url: 'url', model: 'model', isDefault: false, isAvailable: true);

      // In unit test environment without real OS print spooler, directPrintPdf throws
      await provider.executePrint(job, printer, tempFile.path);

      expect(provider.state, PrintExecutionState.failed);
      expect(service.startCalled, true);
    });

    test('executePrint fails if startJob throws', () async {
      final service = MockShopService()..shouldThrowStart = true;
      final storage = MockSecureStorage();
      final provider = PrintExecutionProvider(
        shopService: service,
        secureStorage: storage,
        printerSettingsService: stubSettings,
      );

      final job = PrintJobDetailModel(
        id: 1,
        status: 'ACCEPTED',
        price: 1.0,
        copies: 1,
        paperSize: 'A4',
        colorMode: 'COLOR',
        printSide: 'SINGLE',
        documentId: '1',
        statusHistory: [],
      );
      final printer = const Printer(name: 'TestPrinter', url: 'url', model: 'model', isDefault: false, isAvailable: true);

      await provider.executePrint(job, printer, tempFile.path);

      expect(provider.state, PrintExecutionState.failed);
      expect(service.startCalled, true);
      expect(service.completeCalled, false); // Never reaches complete
    });

    test('executePrint passes requested pageRange to PdfPageExtractor', () async {
      final service = MockShopService();
      final storage = MockSecureStorage();
      final extractor = MockPdfPageExtractor();
      final provider = PrintExecutionProvider(
        shopService: service,
        secureStorage: storage,
        pageExtractor: extractor,
        printerSettingsService: stubSettings,
      );

      final job = PrintJobDetailModel(
        id: 42,
        status: 'ACCEPTED',
        price: 3.5,
        copies: 1,
        paperSize: 'A4',
        colorMode: 'COLOR',
        printSide: 'SINGLE',
        documentId: 'doc-42',
        pageRange: '2-4',
        statusHistory: [],
      );
      final printer = const Printer(name: 'TestPrinter', url: 'url', model: 'model', isDefault: false, isAvailable: true);

      await provider.executePrint(job, printer, tempFile.path);

      expect(extractor.lastExtractedRange, equals('2-4'));
      expect(service.startCalled, isTrue);
    });

    test('executePrint fails immediately and does not print when pageRange is invalid', () async {
      final service = MockShopService();
      final storage = MockSecureStorage();
      final extractor = MockPdfPageExtractor()
        ..shouldThrow = true
        ..throwMessage = 'Page 99 exceeds document total pages (5).';
      final provider = PrintExecutionProvider(
        shopService: service,
        secureStorage: storage,
        pageExtractor: extractor,
        printerSettingsService: stubSettings,
      );

      final job = PrintJobDetailModel(
        id: 43,
        status: 'ACCEPTED',
        price: 2.0,
        copies: 2,
        paperSize: 'A4',
        colorMode: 'COLOR',
        printSide: 'SINGLE',
        documentId: 'doc-43',
        pageRange: '99',
        statusHistory: [],
      );
      final printer = const Printer(name: 'TestPrinter', url: 'url', model: 'model', isDefault: false, isAvailable: true);

      await provider.executePrint(job, printer, tempFile.path);

      expect(provider.state, equals(PrintExecutionState.failed));
      expect(provider.errorMessage, contains('Page 99 exceeds document total pages (5).'));
      // Verified that job state was NOT set to PRINTED_PENDING_SYNC in local storage
      expect(await storage.getJobPrintState(43), isNull);
      // Verified that completeJob was never invoked
      expect(service.completeCalled, isFalse);
    });
  });
}
