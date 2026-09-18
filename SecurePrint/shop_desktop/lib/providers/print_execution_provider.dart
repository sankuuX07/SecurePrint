import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import '../models/print_job_detail_model.dart';
import '../services/shop_service.dart';
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

  PrintExecutionState _state = PrintExecutionState.idle;
  PrintExecutionState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _currentCopy = 0;
  int get currentCopy => _currentCopy;

  PrintJobDetailModel? _job;

  PrintExecutionProvider({
    ShopService? shopService,
  }) : _shopService = shopService ?? ShopService();

  Future<void> executePrint(PrintJobDetailModel job, Printer printer, String localFilePath) async {
    if (_state == PrintExecutionState.starting || _state == PrintExecutionState.printing || _state == PrintExecutionState.syncing) {
      return; // Lock to prevent duplicates
    }

    _job = job;
    _setState(PrintExecutionState.starting);

    try {
      // 1. Transition backend to PRINTING
      try {
        await _shopService.startJob(job.id);
      } catch (e) {
        // If it's already PRINTING (e.g. from a previous failure), we can proceed.
        // But if it's CANCELLED or COMPLETED, we must abort.
        // Let's assume a generic catch and we let it proceed if we can detect it, 
        // but to be safe, if we get an exception we might want to check the message.
        // A 400 "Invalid state transition" usually means it's not ACCEPTED.
        // We'll throw to be safe unless we want to fetch the status again.
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
        
        // Use Printer settings if supported natively, but the package directPrintPdf ignores copies on Windows.
        // Looping ensures N jobs are spooled.
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (_) => pdfBytes,
          name: 'SecurePrint_Job_${job.id}_Copy_$_currentCopy',
          usePrinterSettings: false, 
        );
      }

      // 3. Transition backend to COMPLETED
      _setState(PrintExecutionState.syncing);
      await _shopService.completeJob(job.id);

      // 4. Success
      _setState(PrintExecutionState.completed);

    } catch (e) {
      _errorMessage = e.toString();
      if (_state == PrintExecutionState.syncing) {
        // We printed physically, but failed to tell backend. Keep it in syncing/failed so we can retry.
        _setState(PrintExecutionState.failed); 
      } else {
        _setState(PrintExecutionState.failed);
      }
    }
  }

  Future<void> retrySync() async {
    if (_job == null) return;
    
    _errorMessage = null;
    _setState(PrintExecutionState.syncing);
    try {
      await _shopService.completeJob(_job!.id);
      _setState(PrintExecutionState.completed);
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
