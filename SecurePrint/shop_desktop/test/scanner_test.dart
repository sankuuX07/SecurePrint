import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_desktop/core/networking/api_client.dart';
import 'package:shop_desktop/services/shop_service.dart';
import 'package:shop_desktop/services/secure_storage.dart';
import 'package:shop_desktop/core/errors/api_exception.dart';

class MockSecureStorage extends SecureStorage {
  @override
  Future<String?> getToken() async => 'fake_token';
}

void main() {
  group('Secure QR Scanner Authorization Tests', () {
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
    });

    test('Successful authorization returns expected access_id', () async {
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.contains('/authorize')) {
          return http.Response(
            jsonEncode({
              'access_id': 'access-1234',
              'status': 'AUTHORIZED',
              'expires_at': '2023-01-01T12:00:00Z',
              'print_job_id': 1,
              'document_id': 'doc1'
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);

      final response = await shopService.authorizeDocumentAccess('valid_token');
      
      expect(response['access_id'], 'access-1234');
      expect(response['status'], 'AUTHORIZED');
    });

    test('Expired token throws 403 ApiException', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'Secure access credential is invalid or unavailable.'
          }),
          403,
        );
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);

      expect(
        () => shopService.authorizeDocumentAccess('expired_token'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('Invalid token throws 404 ApiException', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'Secure access credential is invalid or unavailable.'
          }),
          404,
        );
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);

      expect(
        () => shopService.authorizeDocumentAccess('invalid_token'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('401 response throws 401 ApiException (triggering logout)', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'Token expired'
          }),
          401,
        );
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);

      expect(
        () => shopService.authorizeDocumentAccess('some_token'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });
}
