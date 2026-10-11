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

  bool _isLocalSession = false;
  UserModel? _localUser;

  bool get isLocalSession => _isLocalSession;

  Future<void> loadDashboard({bool isLocalSession = false, UserModel? localUser}) async {
    _isLocalSession = isLocalSession;
    _localUser = localUser;

    _state = DashboardState.loading;
    _errorMessage = null;
    notifyListeners();

    if (isLocalSession) {
      _shopProfile = localUser ?? UserModel(
        id: 1,
        name: 'Local Test Owner',
        email: 'local@shop.dev',
        phone: '555-0100',
        role: 'SHOP',
        shopName: 'Local Test Shop (Preview)',
        address: '123 Development Way',
        city: 'Local City',
      );
      _recentJobs = [];
      _state = DashboardState.loaded;
      notifyListeners();
      return;
    }

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
    await loadDashboard(isLocalSession: _isLocalSession, localUser: _localUser);
  }
}
