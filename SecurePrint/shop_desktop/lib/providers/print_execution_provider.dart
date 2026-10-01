import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import '../models/print_job_detail_model.dart';
import '../services/shop_service.dart';
import '../services/secure_storage.dart';
import '../core/errors/api_exception.dart';

enum PrintExecutionState {
  idle,
  starting,
  printing,
  syncing,
  completed,
  failed,
}

class PrintExecutionProvider extends ChangeNotifier {
  final ShopService _shopService;
  final SecureStorage _secureStorage;

  PrintExecutionState _state = PrintExecutionState.idle;
  PrintExecutionState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _currentCopy = 0;
  int get currentCopy => _currentCopy;

  PrintJobDetailModel? _job;

  PrintExecutionProvider({
    ShopService? shopService,
    SecureStorage? secureStorage,
  }) : _shopService = shopService ?? ShopService(),
       _secureStorage = secureStorage ?? SecureStorage();

  Future<void> executePrint(PrintJobDetailModel job, Printer printer, String localFilePath) async {
    if (_state == PrintExecutionState.starting || _state == PrintExecutionState.printing || _state == PrintExecutionState.syncing) {
      return; // Lock to prevent duplicates
    }

    _job = job;
    _setState(PrintExecutionState.starting);

    try {
      // 0. Check local print execution state to prevent duplicate physical prints
      final localState = await _secureStorage.getJobPrintState(job.id);
      if (localState == 'PRINTED_PENDING_SYNC') {
        // Skip physical print and go straight to syncing
        _setState(PrintExecutionState.syncing);
        await _completeBackendSync(job.id);
        return;
      } else if (localState == 'COMPLETED_SYNCED') {
        _setState(PrintExecutionState.completed);
        return;
      }

      // 1. Transition backend to PRINTING
      try {
        await _shopService.startJob(job.id);
      } catch (e) {
        if (e.toString().contains('Invalid state transition')) {
           final currentJob = await _shopService.getPrintJobDetail(job.id);
           if (currentJob.status != 'PRINTING') {
              throw Exception('Job is not in a printable state (${currentJob.status}).');
           }
        } else {
           rethrow;
        }
      }

      // 2. Perform Physical Print
      _setState(PrintExecutionState.printing);
      final file = File(localFilePath);
      if (!await file.exists()) {
        throw Exception('Authorized document file is missing from local temp storage.');
      }
      
      final pdfBytes = await file.readAsBytes();

      for (int i = 0; i < job.copies; i++) {
        _currentCopy = i + 1;
        notifyListeners();
        
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (_) => pdfBytes,
          name: 'SecurePrint_Job_${job.id}_Copy_$_currentCopy',
          usePrinterSettings: false, 
        );
      }

      // 2.5 Persist local state before syncing to prevent duplicate physical printing
      await _secureStorage.saveJobPrintState(job.id, 'PRINTED_PENDING_SYNC');

      // 3. Transition backend to COMPLETED
      _setState(PrintExecutionState.syncing);
      await _completeBackendSync(job.id);

    } catch (e) {
      _errorMessage = e.toString();
      _setState(PrintExecutionState.failed);
    }
  }

  Future<void> _completeBackendSync(int jobId) async {
    try {
      await _shopService.completeJob(jobId);
      await _secureStorage.saveJobPrintState(jobId, 'COMPLETED_SYNCED');
      _setState(PrintExecutionState.completed);
    } catch (e) {
      // If completeJob fails, we stay in syncing/failed state but the local storage 
      // is still PRINTED_PENDING_SYNC, so next time it won't physically print.
      throw e;
    }
  }

  Future<void> retrySync() async {
    if (_job == null) return;
    
    _errorMessage = null;
    _setState(PrintExecutionState.syncing);
    try {
      await _completeBackendSync(_job!.id);
    } catch (e) {
      _errorMessage = 'Failed to sync status: $e';
      _setState(PrintExecutionState.failed);
    }
  }

  void reset() {
    _state = PrintExecutionState.idle;
    _errorMessage = null;
    _currentCopy = 0;
    _job = null;
    notifyListeners();
  }

  void _setState(PrintExecutionState newState) {
    _state = newState;
    notifyListeners();
  }
}
