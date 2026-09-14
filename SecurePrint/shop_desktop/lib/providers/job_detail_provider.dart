import 'package:flutter/material.dart';
import '../services/shop_service.dart';
import '../models/print_job_detail_model.dart';
import '../models/payment_model.dart';
import '../core/errors/api_exception.dart';

enum JobDetailState {
  initial,
  loading,
  loaded,
  error,
  unauthorized,
}

class JobDetailProvider extends ChangeNotifier {
  final ShopService _shopService;
  final int jobId;

  JobDetailState _state = JobDetailState.initial;
  String? _errorMessage;
  
  PrintJobDetailModel? _jobDetail;
  PaymentModel? _payment;
  bool _isActionProcessing = false;

  JobDetailProvider({required this.jobId, ShopService? shopService}) 
      : _shopService = shopService ?? ShopService();

  JobDetailState get state => _state;
  String? get errorMessage => _errorMessage;
  PrintJobDetailModel? get jobDetail => _jobDetail;
  PaymentModel? get payment => _payment;
  bool get isActionProcessing => _isActionProcessing;

  Future<void> loadJob() async {
    _state = JobDetailState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final futures = await Future.wait([
        _shopService.getPrintJobDetail(jobId),
        _shopService.getJobPayment(jobId).catchError((e) {
          // If payment doesn't exist or errors out, don't fail the whole view
          return null;
        }),
      ]);

      _jobDetail = futures[0] as PrintJobDetailModel;
      _payment = futures[1] as PaymentModel?;
      
      _state = JobDetailState.loaded;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        _state = JobDetailState.unauthorized;
      } else {
        _state = JobDetailState.error;
        _errorMessage = e.message;
      }
    } catch (e) {
      _state = JobDetailState.error;
      _errorMessage = 'An unexpected error occurred while loading job details.';
    }
    
    notifyListeners();
  }

  Future<void> acceptJob() async {
    await _performAction(() => _shopService.acceptJob(jobId));
  }

  Future<void> startJob() async {
    await _performAction(() => _shopService.startJob(jobId));
  }

  Future<void> completeJob() async {
    await _performAction(() => _shopService.completeJob(jobId));
  }

  Future<void> _performAction(Future<dynamic> Function() action) async {
    if (_isActionProcessing) return;
    
    _isActionProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      // Reload job details to get fresh state and history
      await loadJob();
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        _state = JobDetailState.unauthorized;
      } else {
        _errorMessage = e.message;
      }
    } catch (e) {
      _errorMessage = 'An unexpected error occurred while performing the action.';
    } finally {
      _isActionProcessing = false;
      notifyListeners();
    }
  }
}
