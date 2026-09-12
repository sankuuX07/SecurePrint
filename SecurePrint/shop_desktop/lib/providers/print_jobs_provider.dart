import 'package:flutter/material.dart';
import '../services/shop_service.dart';
import '../models/print_job_model.dart';
import '../core/errors/api_exception.dart';

enum PrintJobsState {
  initial,
  loading,
  loaded,
  error,
  unauthorized,
}

class PrintJobsProvider extends ChangeNotifier {
  final ShopService _shopService;
  
  PrintJobsState _state = PrintJobsState.initial;
  String? _errorMessage;
  List<PrintJobModel> _jobs = [];
  
  int _currentPage = 1;
  final int _pageSize = 20;
  String? _selectedStatus;
  bool _hasNextPage = true;

  PrintJobsProvider({ShopService? shopService}) 
      : _shopService = shopService ?? ShopService();

  PrintJobsState get state => _state;
  String? get errorMessage => _errorMessage;
  List<PrintJobModel> get jobs => _jobs;
  int get currentPage => _currentPage;
  String? get selectedStatus => _selectedStatus;
  bool get hasNextPage => _hasNextPage;

  Future<void> loadJobs({bool reset = false}) async {
    if (reset) {
      _currentPage = 1;
      _hasNextPage = true;
    }

    _state = PrintJobsState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetchedJobs = await _shopService.getRecentJobs(
        page: _currentPage, 
        pageSize: _pageSize,
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      );

      if (reset) {
        _jobs = fetchedJobs;
      } else {
        _jobs.addAll(fetchedJobs);
      }

      _hasNextPage = fetchedJobs.length == _pageSize;
      _state = PrintJobsState.loaded;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        _state = PrintJobsState.unauthorized;
      } else {
        _state = PrintJobsState.error;
        _errorMessage = e.message;
      }
    } catch (e) {
      _state = PrintJobsState.error;
      _errorMessage = 'An unexpected error occurred.';
    }
    
    notifyListeners();
  }

  void setFilter(String? status) {
    if (_selectedStatus == status) return;
    _selectedStatus = status;
    loadJobs(reset: true);
  }

  Future<void> nextPage() async {
    if (!_hasNextPage || _state == PrintJobsState.loading) return;
    _currentPage++;
    await loadJobs(reset: true); // Doing absolute pagination instead of infinite scroll for Desktop
  }

  Future<void> previousPage() async {
    if (_currentPage <= 1 || _state == PrintJobsState.loading) return;
    _currentPage--;
    await loadJobs(reset: true);
  }

  Future<void> refresh() async {
    await loadJobs(reset: true);
  }
}
