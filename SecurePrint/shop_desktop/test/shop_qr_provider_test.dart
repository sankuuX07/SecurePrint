import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_desktop/core/networking/api_client.dart';
import 'package:shop_desktop/services/shop_service.dart';
import 'package:shop_desktop/providers/shop_qr_provider.dart';
import 'package:shop_desktop/services/secure_storage.dart';

class MockSecureStorage extends SecureStorage {
  @override
  Future<String?> getToken() async => 'fake_token';
}

void main() {
  group('ShopQrProvider Tests', () {
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
    });

    test('Initial load fetches QR details and sets loaded state', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'qr_identifier': 'SP-SHOP-123',
            'status': 'ACTIVE',
            'created_at': '2023-01-01T12:00:00Z'
          }),
          200,
        );
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final provider = ShopQrProvider(shopService: shopService);

      expect(provider.state, ShopQrState.initial);
      
      await provider.loadQr();
      
      expect(provider.state, ShopQrState.loaded);
      expect(provider.shopQr?.qrIdentifier, 'SP-SHOP-123');
      expect(provider.shopQr?.status, 'ACTIVE');
    });

    test('Regenerate QR updates QR identifier', () async {
      bool regenerateCalled = false;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.contains('regenerate')) {
          regenerateCalled = true;
          return http.Response(
            jsonEncode({
              'qr_identifier': 'SP-SHOP-456',
              'status': 'ACTIVE',
              'created_at': '2023-01-02T12:00:00Z'
            }),
            200,
          );
        } else {
          return http.Response(
            jsonEncode({
              'qr_identifier': regenerateCalled ? 'SP-SHOP-456' : 'SP-SHOP-123',
              'status': 'ACTIVE',
              'created_at': '2023-01-01T12:00:00Z'
            }),
            200,
          );
        }
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);
      final shopService = ShopService(apiClient: apiClient);
      final provider = ShopQrProvider(shopService: shopService);

      await provider.loadQr();
      expect(provider.shopQr?.qrIdentifier, 'SP-SHOP-123');

      await provider.regenerateQr();
      
      expect(regenerateCalled, true);
      expect(provider.shopQr?.qrIdentifier, 'SP-SHOP-456');
    });
  });
}
