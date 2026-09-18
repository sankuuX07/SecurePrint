import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shop_desktop/core/networking/api_client.dart';
import 'package:shop_desktop/core/errors/api_exception.dart';
import 'package:shop_desktop/services/secure_storage.dart';
import 'dart:io';

class MockSecureStorage extends SecureStorage {
  @override
  Future<String?> getToken() async => 'fake_token';
}

void main() {
  group('ApiClient Error Mapping Tests', () {
    late MockSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
    });

    test('401 maps to session expired message', () async {
      final client = MockClient((request) async {
        return http.Response('{"detail":"Token expired"}', 401);
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);

      expect(
        () async => await apiClient.get('/test'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'Your session has expired. Please log in again.')),
      );
    });

    test('403 maps to unauthorized message', () async {
      final client = MockClient((request) async {
        return http.Response('{"detail":"Forbidden"}', 403);
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);

      expect(
        () async => await apiClient.get('/test'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'You are not authorized to perform this action.')),
      );
    });

    test('404 maps to not found message', () async {
      final client = MockClient((request) async {
        return http.Response('{"detail":"Not found"}', 404);
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);

      expect(
        () async => await apiClient.get('/test'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'The requested item could not be found.')),
      );
    });

    test('500 maps to server error message', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);

      expect(
        () async => await apiClient.get('/test'),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'SecurePrint server encountered an error.')),
      );
    });

    test('SocketException maps to backend connection error', () async {
      final client = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final apiClient = ApiClient(client: client, secureStorage: mockStorage);

      expect(
        () async => await apiClient.get('/test'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'Unable to connect to the SecurePrint server. Please check the backend connection.')),
      );
    });
  });
}
