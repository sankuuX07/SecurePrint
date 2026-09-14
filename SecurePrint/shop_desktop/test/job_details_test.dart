import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_desktop/core/networking/api_client.dart';
import 'package:shop_desktop/services/shop_service.dart';
import 'package:shop_desktop/providers/job_detail_provider.dart';
import 'package:shop_desktop/services/secure_storage.dart';

class MockSecureStorage extends SecureStorage {
  @override
  Future<String?> getToken() async => 'fake_token';
}

void main() {
  group('JobDetailProvider Tests', () {
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
    });

    test('Initial load fetches job details and sets loaded state', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/payment')) {
          return http.Response(
            jsonEncode({
              'id': 1,
              'print_job_id': 1,
              'amount': 10.0,
              'method': 'PAY_AT_SHOP',
              'status': 'UNPAID',
              'created_at': '2023-01-01T12:00:00Z'
            }),
            200,
          );
        } else {
          return http.Response(
            jsonEncode({
              'id': 1,
              'status': 'CREATED',
              'price': 10.0,
              'copies': 1,
              'paper_size': 'A4',
              'color_mode': 'BW',
              'print_side': 'SINGLE',
              'document_id': 'doc1',
              'status_history': [
                {
                  'id': 1,
                  'to_status': 'CREATED',
                  'changed_at': '2023-01-01T12:00:00Z'
                }
              ]
            }),
            200,
          );
        }
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final provider = JobDetailProvider(jobId: 1, shopService: shopService);

      expect(provider.state, JobDetailState.initial);
      
      await provider.loadJob();
      
      expect(provider.state, JobDetailState.loaded);
      expect(provider.jobDetail?.id, 1);
      expect(provider.payment?.status, 'UNPAID');
    });

    test('401 response sets state to unauthorized', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final provider = JobDetailProvider(jobId: 1, shopService: shopService);

      await provider.loadJob();
      
      expect(provider.state, JobDetailState.unauthorized);
    });

    test('Accept job sets processing state and updates job', () async {
      bool acceptCalled = false;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.contains('accept')) {
          acceptCalled = true;
          return http.Response(
            jsonEncode({
              'id': 1,
              'status': 'ACCEPTED',
              'price': 10.0,
              'copies': 1,
              'paper_size': 'A4',
              'color_mode': 'BW',
              'print_side': 'SINGLE',
              'document_id': 'doc1',
            }),
            200,
          );
        } else if (request.url.path.contains('/payment')) {
          return http.Response(
            jsonEncode({
              'id': 1,
              'print_job_id': 1,
              'amount': 10.0,
              'method': 'PAY_AT_SHOP',
              'status': 'UNPAID',
              'created_at': '2023-01-01T12:00:00Z'
            }),
            200,
          );
        } else {
          // Mock loadJob response
          return http.Response(
            jsonEncode({
              'id': 1,
              'status': acceptCalled ? 'ACCEPTED' : 'CREATED',
              'price': 10.0,
              'copies': 1,
              'paper_size': 'A4',
              'color_mode': 'BW',
              'print_side': 'SINGLE',
              'document_id': 'doc1',
              'status_history': []
            }),
            200,
          );
        }
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final provider = JobDetailProvider(jobId: 1, shopService: shopService);

      await provider.loadJob();
      expect(provider.jobDetail?.status, 'CREATED');

      await provider.acceptJob();
      
      expect(acceptCalled, true);
      expect(provider.jobDetail?.status, 'ACCEPTED');
    });
  });
}
