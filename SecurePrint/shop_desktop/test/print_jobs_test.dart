import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_desktop/core/networking/api_client.dart';
import 'package:shop_desktop/services/shop_service.dart';
import 'package:shop_desktop/providers/print_jobs_provider.dart';
import 'package:shop_desktop/core/errors/api_exception.dart';
import 'package:shop_desktop/services/secure_storage.dart';

class MockSecureStorage extends SecureStorage {
  @override
  Future<String?> getToken() async => 'fake_token';
}

void main() {
  group('PrintJobsProvider Tests', () {
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
    });

    test('Initial load fetches jobs and sets loaded state', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['page'], '1');
        expect(request.url.queryParameters['page_size'], '20');
        expect(request.url.queryParameters.containsKey('status'), false);
        return http.Response(
          jsonEncode([
            {'id': 1, 'status': 'CREATED', 'price': 10.0, 'copies': 1, 'paper_size': 'A4', 'color_mode': 'BW', 'print_side': 'SINGLE', 'document_id': 'doc1'},
          ]),
          200,
        );
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final provider = PrintJobsProvider(shopService: shopService);

      expect(provider.state, PrintJobsState.initial);
      
      await provider.loadJobs(reset: true);
      
      expect(provider.state, PrintJobsState.loaded);
      expect(provider.jobs.length, 1);
      expect(provider.hasNextPage, false); // Length < 20
    });

    test('Filtering by status adds query parameter', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['status'], 'SENT_TO_SHOP');
        return http.Response(jsonEncode([]), 200);
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final provider = PrintJobsProvider(shopService: shopService);

      provider.setFilter('SENT_TO_SHOP');
      await Future.delayed(const Duration(milliseconds: 100)); // wait for loadJobs
      
      expect(provider.selectedStatus, 'SENT_TO_SHOP');
      expect(provider.jobs.isEmpty, true);
    });

    test('401 response sets state to unauthorized', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final provider = PrintJobsProvider(shopService: shopService);

      await provider.loadJobs(reset: true);
      
      expect(provider.state, PrintJobsState.unauthorized);
    });
  });
}
