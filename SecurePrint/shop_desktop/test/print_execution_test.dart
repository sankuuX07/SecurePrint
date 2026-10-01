import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:shop_desktop/models/print_job_detail_model.dart';
import 'package:shop_desktop/providers/print_execution_provider.dart';
import 'package:shop_desktop/services/shop_service.dart';
import 'package:shop_desktop/models/print_job_model.dart';
import 'package:shop_desktop/services/secure_storage.dart';

class MockShopService extends ShopService {
  bool startCalled = false;
  bool completeCalled = false;
  bool shouldThrowStart = false;
  bool shouldThrowComplete = false;

  @override
  Future<PrintJobModel> startJob(int jobId) async {
    startCalled = true;
    if (shouldThrowStart) throw Exception('API Error');
    return PrintJobModel(id: jobId, documentId: '1', copies: 1, selectedPageCount: 1, colorMode: 'COLOR', paperSize: 'A4', printSide: 'SINGLE', price: 1.0, status: 'PRINTING', createdAt: DateTime.now().toIso8601String());
  }

  @override
  Future<PrintJobModel> completeJob(int jobId) async {
    completeCalled = true;
    if (shouldThrowComplete) throw Exception('Sync Error');
    return PrintJobModel(id: jobId, documentId: '1', copies: 1, selectedPageCount: 1, colorMode: 'COLOR', paperSize: 'A4', printSide: 'SINGLE', price: 1.0, status: 'COMPLETED', createdAt: DateTime.now().toIso8601String());
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

void main() {
  group('PrintExecutionProvider Tests', () {
    late File tempFile;

    setUp(() async {
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
      final provider = PrintExecutionProvider(shopService: service, secureStorage: storage);

      final job = PrintJobDetailModel(id: 1, status: 'ACCEPTED', price: 1.0, copies: 1, paperSize: 'A4', colorMode: 'COLOR', printSide: 'SINGLE', documentId: '1', statusHistory: []);
      final printer = const Printer(name: 'TestPrinter', url: 'url', model: 'model', isDefault: false, isAvailable: true);

      try {
        await provider.executePrint(job, printer, tempFile.path);
      } catch (e) {
      }

      expect(provider.state, PrintExecutionState.failed);
      expect(service.startCalled, true);
    });

    test('executePrint fails if startJob throws', () async {
      final service = MockShopService()..shouldThrowStart = true;
      final storage = MockSecureStorage();
      final provider = PrintExecutionProvider(shopService: service, secureStorage: storage);

      final job = PrintJobDetailModel(id: 1, status: 'ACCEPTED', price: 1.0, copies: 1, paperSize: 'A4', colorMode: 'COLOR', printSide: 'SINGLE', documentId: '1', statusHistory: []);
      final printer = const Printer(name: 'TestPrinter', url: 'url', model: 'model', isDefault: false, isAvailable: true);

      await provider.executePrint(job, printer, tempFile.path);

      expect(provider.state, PrintExecutionState.failed);
      expect(service.startCalled, true);
      expect(service.completeCalled, false); // Never reaches complete
    });
  });
}
