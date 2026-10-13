import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:shop_desktop/models/print_job_detail_model.dart';
import 'package:shop_desktop/models/print_job_model.dart';
import 'package:shop_desktop/models/print_settings.dart';
import 'package:shop_desktop/providers/print_execution_provider.dart';
import 'package:shop_desktop/providers/printer_provider.dart';
import 'package:shop_desktop/services/printer_service.dart';
import 'package:shop_desktop/services/printer_settings_service.dart';
import 'package:shop_desktop/services/secure_storage.dart';
import 'package:shop_desktop/services/shop_service.dart';

class MockPrinterSettingsService implements PrinterSettingsService {
  PrinterCapabilities capabilities;
  bool shouldThrowOnApply;
  String throwMessage;

  String? lastPrinterName;
  PrintDuplexMode? lastDuplexMode;
  PrintColorMode? lastColorMode;

  MockPrinterSettingsService({
    this.capabilities = const PrinterCapabilities(supportsDuplex: true, supportsColor: true),
    this.shouldThrowOnApply = false,
    this.throwMessage = 'Unsupported printer setting.',
  });

  @override
  Future<PrinterCapabilities> getCapabilities(String printerName) async {
    lastPrinterName = printerName;
    return capabilities;
  }

  @override
  Future<PrinterSettingsApplicationResult> applySettings(
    String printerName, {
    required PrintDuplexMode duplexMode,
    required PrintColorMode colorMode,
  }) async {
    lastPrinterName = printerName;
    lastDuplexMode = duplexMode;
    lastColorMode = colorMode;

    if (shouldThrowOnApply) {
      throw UnsupportedPrinterSettingException(throwMessage);
    }

    if (duplexMode == PrintDuplexMode.duplex && !capabilities.supportsDuplex) {
      throw UnsupportedPrinterSettingException(
        "Printer '$printerName' does not support duplex (two-sided) printing.",
      );
    }

    if (colorMode == PrintColorMode.color && !capabilities.supportsColor) {
      throw UnsupportedPrinterSettingException(
        "Printer '$printerName' is a monochrome printer and does not support color printing.",
      );
    }

    return PrinterSettingsApplicationResult(
      applied: true,
      duplexApplied: duplexMode == PrintDuplexMode.duplex,
      colorApplied: colorMode == PrintColorMode.color,
    );
  }
}

class MockShopService extends ShopService {
  bool startCalled = false;
  bool completeCalled = false;

  @override
  Future<PrintJobModel> startJob(int jobId) async {
    startCalled = true;
    return PrintJobModel(
      id: jobId,
      documentId: 'doc-$jobId',
      copies: 1,
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
    return PrintJobModel(
      id: jobId,
      documentId: 'doc-$jobId',
      copies: 1,
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

  @override
  Future<String?> getPreferredPrinter() async {
    return _storage['preferred_printer'];
  }

  @override
  Future<void> savePreferredPrinter(String name) async {
    _storage['preferred_printer'] = name;
  }
}

class MockPrinterService extends PrinterService {
  final List<Printer> mockPrinters;
  MockPrinterService(this.mockPrinters);

  @override
  Future<List<Printer>> getPrinters() async => mockPrinters;

  @override
  Future<Printer?> getDefaultPrinter() async {
    return mockPrinters.isNotEmpty ? mockPrinters.first : null;
  }
}

void main() {
  group('PrintDuplexMode Model Tests', () {
    test('parses simplex / single-sided strings correctly', () {
      expect(PrintDuplexMode.fromJobString('SINGLE'), equals(PrintDuplexMode.simplex));
      expect(PrintDuplexMode.fromJobString('single'), equals(PrintDuplexMode.simplex));
      expect(PrintDuplexMode.fromJobString('SIMPLEX'), equals(PrintDuplexMode.simplex));
      expect(PrintDuplexMode.fromJobString('ONE_SIDED'), equals(PrintDuplexMode.simplex));
      expect(PrintDuplexMode.fromJobString('1'), equals(PrintDuplexMode.simplex));
      expect(PrintDuplexMode.fromJobString(null), equals(PrintDuplexMode.simplex));
      expect(PrintDuplexMode.fromJobString(''), equals(PrintDuplexMode.simplex));
      expect(PrintDuplexMode.fromJobString('   '), equals(PrintDuplexMode.simplex));
    });

    test('parses duplex / double-sided strings correctly', () {
      expect(PrintDuplexMode.fromJobString('DOUBLE'), equals(PrintDuplexMode.duplex));
      expect(PrintDuplexMode.fromJobString('double'), equals(PrintDuplexMode.duplex));
      expect(PrintDuplexMode.fromJobString('DUPLEX'), equals(PrintDuplexMode.duplex));
      expect(PrintDuplexMode.fromJobString('TWO_SIDED'), equals(PrintDuplexMode.duplex));
      expect(PrintDuplexMode.fromJobString('2'), equals(PrintDuplexMode.duplex));
    });

    test('rejects unrecognized duplex strings with clear exception', () {
      expect(
        () => PrintDuplexMode.fromJobString('TRIPLE'),
        throwsA(isA<UnsupportedPrinterSettingException>().having(
          (e) => e.message,
          'message',
          contains("Unrecognized print side setting: 'TRIPLE'"),
        )),
      );
    });
  });

  group('PrintColorMode Model Tests', () {
    test('parses color strings correctly', () {
      expect(PrintColorMode.fromJobString('COLOR'), equals(PrintColorMode.color));
      expect(PrintColorMode.fromJobString('color'), equals(PrintColorMode.color));
      expect(PrintColorMode.fromJobString('COLOUR'), equals(PrintColorMode.color));
      expect(PrintColorMode.fromJobString(null), equals(PrintColorMode.color));
      expect(PrintColorMode.fromJobString(''), equals(PrintColorMode.color));
      expect(PrintColorMode.fromJobString('   '), equals(PrintColorMode.color));
    });

    test('parses monochrome / black-and-white strings correctly', () {
      expect(PrintColorMode.fromJobString('BW'), equals(PrintColorMode.monochrome));
      expect(PrintColorMode.fromJobString('B/W'), equals(PrintColorMode.monochrome));
      expect(PrintColorMode.fromJobString('b/w'), equals(PrintColorMode.monochrome));
      expect(PrintColorMode.fromJobString('BLACK_AND_WHITE'), equals(PrintColorMode.monochrome));
      expect(PrintColorMode.fromJobString('MONOCHROME'), equals(PrintColorMode.monochrome));
      expect(PrintColorMode.fromJobString('GRAYSCALE'), equals(PrintColorMode.monochrome));
      expect(PrintColorMode.fromJobString('GREYSCALE'), equals(PrintColorMode.monochrome));
    });

    test('rejects unrecognized color strings with clear exception', () {
      expect(
        () => PrintColorMode.fromJobString('SEPIA'),
        throwsA(isA<UnsupportedPrinterSettingException>().having(
          (e) => e.message,
          'message',
          contains("Unrecognized color mode setting: 'SEPIA'"),
        )),
      );
    });
  });

  group('PrintExecutionProvider Settings Propagation Tests', () {
    late File tempFile;
    const testPrinter = Printer(
      name: 'HP LaserJet Pro',
      url: 'url',
      model: 'model',
      isDefault: true,
      isAvailable: true,
    );

    setUp(() async {
      tempFile = File('test_settings_dummy.pdf');
      await tempFile.writeAsBytes([1, 2, 3]);
    });

    tearDown(() async {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    test('propagates duplex and color settings to PrinterSettingsService', () async {
      final mockSettings = MockPrinterSettingsService(
        capabilities: const PrinterCapabilities(supportsDuplex: true, supportsColor: true),
      );
      final shopService = MockShopService();
      final secureStorage = MockSecureStorage();

      final provider = PrintExecutionProvider(
        shopService: shopService,
        secureStorage: secureStorage,
        printerSettingsService: mockSettings,
      );

      final job = PrintJobDetailModel(
        id: 101,
        status: 'ACCEPTED',
        price: 5.0,
        copies: 1,
        paperSize: 'A4',
        colorMode: 'BW',
        printSide: 'DOUBLE',
        documentId: 'doc-101',
        statusHistory: [],
      );

      await provider.executePrint(job, testPrinter, tempFile.path);

      // Verify settings were propagated accurately
      expect(mockSettings.lastPrinterName, equals('HP LaserJet Pro'));
      expect(mockSettings.lastDuplexMode, equals(PrintDuplexMode.duplex));
      expect(mockSettings.lastColorMode, equals(PrintColorMode.monochrome));
    });

    test('defaults to simplex and color when job settings are blank or single', () async {
      final mockSettings = MockPrinterSettingsService(
        capabilities: const PrinterCapabilities(supportsDuplex: true, supportsColor: true),
      );
      final provider = PrintExecutionProvider(
        shopService: MockShopService(),
        secureStorage: MockSecureStorage(),
        printerSettingsService: mockSettings,
      );

      final job = PrintJobDetailModel(
        id: 102,
        status: 'ACCEPTED',
        price: 2.0,
        copies: 1,
        paperSize: 'A4',
        colorMode: 'COLOR',
        printSide: 'SINGLE',
        documentId: 'doc-102',
        statusHistory: [],
      );

      await provider.executePrint(job, testPrinter, tempFile.path);

      expect(mockSettings.lastDuplexMode, equals(PrintDuplexMode.simplex));
      expect(mockSettings.lastColorMode, equals(PrintColorMode.color));
    });

    test('fails immediately with actionable error when printer lacks duplex support', () async {
      // Simplex-only printer
      final mockSettings = MockPrinterSettingsService(
        capabilities: const PrinterCapabilities(supportsDuplex: false, supportsColor: true),
      );
      final shopService = MockShopService();
      final secureStorage = MockSecureStorage();

      final provider = PrintExecutionProvider(
        shopService: shopService,
        secureStorage: secureStorage,
        printerSettingsService: mockSettings,
      );

      final job = PrintJobDetailModel(
        id: 103,
        status: 'ACCEPTED',
        price: 5.0,
        copies: 1,
        paperSize: 'A4',
        colorMode: 'COLOR',
        printSide: 'DOUBLE', // Requested duplex
        documentId: 'doc-103',
        statusHistory: [],
      );

      await provider.executePrint(job, testPrinter, tempFile.path);

      // Must fail execution and report unsupported duplex
      expect(provider.state, equals(PrintExecutionState.failed));
      expect(
        provider.errorMessage,
        contains("Printer 'HP LaserJet Pro' does not support duplex (two-sided) printing."),
      );
      // Local storage must NOT be marked as PRINTED_PENDING_SYNC
      expect(await secureStorage.getJobPrintState(103), isNull);
      // Backend must NOT be completed
      expect(shopService.completeCalled, isFalse);
    });

    test('fails immediately with actionable error when printer lacks color support', () async {
      // Monochrome-only printer
      final mockSettings = MockPrinterSettingsService(
        capabilities: const PrinterCapabilities(supportsDuplex: true, supportsColor: false),
      );
      final shopService = MockShopService();
      final secureStorage = MockSecureStorage();

      final provider = PrintExecutionProvider(
        shopService: shopService,
        secureStorage: secureStorage,
        printerSettingsService: mockSettings,
      );

      final job = PrintJobDetailModel(
        id: 104,
        status: 'ACCEPTED',
        price: 8.0,
        copies: 1,
        paperSize: 'A4',
        colorMode: 'COLOR', // Requested color on mono printer
        printSide: 'SINGLE',
        documentId: 'doc-104',
        statusHistory: [],
      );

      await provider.executePrint(job, testPrinter, tempFile.path);

      expect(provider.state, equals(PrintExecutionState.failed));
      expect(
        provider.errorMessage,
        contains("Printer 'HP LaserJet Pro' is a monochrome printer and does not support color printing."),
      );
      expect(await secureStorage.getJobPrintState(104), isNull);
      expect(shopService.completeCalled, isFalse);
    });

    test('fails immediately when printSide setting string is malformed', () async {
      final mockSettings = MockPrinterSettingsService();
      final provider = PrintExecutionProvider(
        shopService: MockShopService(),
        secureStorage: MockSecureStorage(),
        printerSettingsService: mockSettings,
      );

      final job = PrintJobDetailModel(
        id: 105,
        status: 'ACCEPTED',
        price: 2.0,
        copies: 1,
        paperSize: 'A4',
        colorMode: 'COLOR',
        printSide: 'TRIPLEX_INVALID',
        documentId: 'doc-105',
        statusHistory: [],
      );

      await provider.executePrint(job, testPrinter, tempFile.path);

      expect(provider.state, equals(PrintExecutionState.failed));
      expect(provider.errorMessage, contains("Unrecognized print side setting: 'TRIPLEX_INVALID'"));
    });
  });

  group('PrinterProvider Capabilities Integration Tests', () {
    test('loads printer capabilities when printer is selected', () async {
      const p1 = Printer(name: 'Printer A', url: 'urlA', isDefault: true, isAvailable: true);
      const p2 = Printer(name: 'Printer B', url: 'urlB', isDefault: false, isAvailable: true);

      final mockSettings = MockPrinterSettingsService(
        capabilities: const PrinterCapabilities(supportsDuplex: true, supportsColor: false),
      );

      final provider = PrinterProvider(
        printerService: MockPrinterService([p1, p2]),
        secureStorage: MockSecureStorage(),
        printerSettingsService: mockSettings,
      );

      await provider.loadPrinters();

      expect(provider.selectedPrinter?.name, equals('Printer A'));
      expect(provider.selectedPrinterCapabilities?.supportsDuplex, isTrue);
      expect(provider.selectedPrinterCapabilities?.supportsColor, isFalse);

      // Now switch to Printer B
      await provider.selectPrinter(p2);
      expect(provider.selectedPrinter?.name, equals('Printer B'));
      expect(mockSettings.lastPrinterName, equals('Printer B'));
    });
  });
}
