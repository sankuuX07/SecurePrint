import 'package:flutter/material.dart';
import '../services/shop_service.dart';
import '../models/user_model.dart';
import '../models/print_job_model.dart';
import '../core/errors/api_exception.dart';

enum DashboardState {
  initial,
  loading,
  loaded,
  error,
  unauthorized,
}

class DashboardProvider extends ChangeNotifier {
  final ShopService _shopService;
  
  DashboardState _state = DashboardState.initial;
  String? _errorMessage;
  UserModel? _shopProfile;
  List<PrintJobModel> _recentJobs = [];

  DashboardProvider({ShopService? shopService}) 
      : _shopService = shopService ?? ShopService();

  DashboardState get state => _state;
  String? get errorMessage => _errorMessage;
  UserModel? get shopProfile => _shopProfile;
  List<PrintJobModel> get recentJobs => _recentJobs;

  // Computed Statistics
  int get pendingJobsCount => _recentJobs.where((j) => j.status == 'CREATED' || j.status == 'SENT_TO_SHOP').length;
  int get acceptedJobsCount => _recentJobs.where((j) => j.status == 'ACCEPTED').length;
  int get printingJobsCount => _recentJobs.where((j) => j.status == 'PRINTING').length;
  int get completedJobsCount => _recentJobs.where((j) => j.status == 'COMPLETED').length;
  int get cancelledJobsCount => _recentJobs.where((j) => j.status == 'CANCELLED').length;

  Future<void> loadDashboard() async {
    _state = DashboardState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _shopProfile = await _shopService.getShopProfile();
      _recentJobs = await _shopService.getRecentJobs(page: 1, pageSize: 100);
      _state = DashboardState.loaded;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        _state = DashboardState.unauthorized;
      } else {
        _state = DashboardState.error;
        _errorMessage = e.message;
      }
    } catch (e) {
      _state = DashboardState.error;
      _errorMessage = 'An unexpected error occurred.';
    }
    
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadDashboard();
  }
}
