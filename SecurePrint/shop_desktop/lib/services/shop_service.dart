import '../core/networking/api_client.dart';
import '../models/user_model.dart';
import '../models/print_job_model.dart';
import '../models/print_job_detail_model.dart';
import '../models/payment_model.dart';
import '../models/shop_qr_model.dart';


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

  Future<PrintJobDetailModel> getPrintJobDetail(int jobId) async {
    final response = await _apiClient.get('/api/v1/print-jobs/shop/$jobId');
    return PrintJobDetailModel.fromJson(response);
  }

  Future<PaymentModel> getJobPayment(int jobId) async {
    final response = await _apiClient.get('/api/v1/shop/print-jobs/$jobId/payment');
    return PaymentModel.fromJson(response);
  }

  Future<PaymentModel> markPaymentPaid(int jobId) async {
    final response = await _apiClient.post('/api/v1/shop/print-jobs/$jobId/payment/mark-paid');
    return PaymentModel.fromJson(response);
  }

  Future<PrintJobModel> acceptJob(int jobId) async {
    final response = await _apiClient.post('/api/v1/print-jobs/$jobId/accept');
    return PrintJobModel.fromJson(response);
  }

  Future<PrintJobModel> startJob(int jobId) async {
    final response = await _apiClient.post('/api/v1/print-jobs/$jobId/start');
    return PrintJobModel.fromJson(response);
  }

  Future<PrintJobModel> completeJob(int jobId) async {
    final response = await _apiClient.post('/api/v1/print-jobs/$jobId/complete');
    return PrintJobModel.fromJson(response);
  }

  Future<Map<String, dynamic>> authorizeDocumentAccess(String token) async {
    final response = await _apiClient.post(
      '/api/v1/shop/document-access/authorize',
      body: {'token': token},
    );
    return response as Map<String, dynamic>;
  }

  Future<ShopQrModel> getShopQr() async {
    final response = await _apiClient.get('/api/v1/shop/qr');
    return ShopQrModel.fromJson(response);
  }

  Future<ShopQrModel> regenerateShopQr() async {
    final response = await _apiClient.post('/api/v1/shop/qr/regenerate');
    return ShopQrModel.fromJson(response);
  }
}
