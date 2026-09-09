import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_desktop/core/networking/api_client.dart';
import 'package:shop_desktop/services/shop_service.dart';
import 'package:shop_desktop/providers/dashboard_provider.dart';
import 'package:shop_desktop/core/errors/api_exception.dart';
import 'package:shop_desktop/services/secure_storage.dart';

class MockSecureStorage extends SecureStorage {
  @override
  Future<String?> getToken() async => 'fake_token';
}

void main() {
  group('DashboardProvider Tests', () {
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
    });

    test('Successful dashboard load sets state and computes statistics', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/users/me')) {
          return http.Response(
            jsonEncode({
              'id': 1,
              'name': 'Test Shop',
              'email': 'shop@test.com',
              'phone': '1234567890',
              'role': 'SHOP',
              'shop_name': 'My Shop',
              'address': '123 Main St',
              'city': 'Test City',
            }),
            200,
          );
        } else if (request.url.path.contains('/print-jobs/shop')) {
          return http.Response(
            jsonEncode([
              {'id': 1, 'status': 'CREATED', 'price': 10.0, 'copies': 1, 'paper_size': 'A4', 'color_mode': 'BW', 'print_side': 'SINGLE', 'document_id': 'doc1'},
              {'id': 2, 'status': 'ACCEPTED', 'price': 15.0, 'copies': 2, 'paper_size': 'A4', 'color_mode': 'COLOR', 'print_side': 'DOUBLE', 'document_id': 'doc2'},
              {'id': 3, 'status': 'COMPLETED', 'price': 5.0, 'copies': 1, 'paper_size': 'A3', 'color_mode': 'BW', 'print_side': 'SINGLE', 'document_id': 'doc3'},
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final provider = DashboardProvider(shopService: shopService);

      expect(provider.state, DashboardState.initial);
      
      await provider.loadDashboard();
      
      expect(provider.state, DashboardState.loaded);
      expect(provider.shopProfile?.shopName, 'My Shop');
      expect(provider.recentJobs.length, 3);
      
      // Test computed statistics
      expect(provider.pendingJobsCount, 1);
      expect(provider.acceptedJobsCount, 1);
      expect(provider.completedJobsCount, 1);
      expect(provider.printingJobsCount, 0);
      expect(provider.cancelledJobsCount, 0);
    });

    test('401 response sets state to unauthorized', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final provider = DashboardProvider(shopService: shopService);

      await provider.loadDashboard();
      
      expect(provider.state, DashboardState.unauthorized);
    });

    test('500 Server error sets error state', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final provider = DashboardProvider(shopService: shopService);

      await provider.loadDashboard();
      
      expect(provider.state, DashboardState.error);
      expect(provider.errorMessage, contains('Internal Server Error'));
    });
  });
}
