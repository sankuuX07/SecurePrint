import '../core/networking/api_client.dart';
import '../models/user_model.dart';
import '../models/print_job_model.dart';

class ShopService {
  final ApiClient _apiClient;

  ShopService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<UserModel> getShopProfile() async {
    final response = await _apiClient.get('/api/v1/users/me');
    return UserModel.fromJson(response);
  }

  Future<List<PrintJobModel>> getRecentJobs({int page = 1, int pageSize = 100, String? status}) async {
    String url = '/api/v1/print-jobs/shop?page=$page&page_size=$pageSize';
    if (status != null && status.isNotEmpty) {
      url += '&status=$status';
    }
    final response = await _apiClient.get(url);
    if (response is List) {
      return response.map((json) => PrintJobModel.fromJson(json)).toList();
    }
    return [];
  }
}
