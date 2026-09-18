import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../errors/api_exception.dart';
import '../../services/secure_storage.dart';

class ApiClient {
  final http.Client _client;
  final SecureStorage _secureStorage;
  final Duration timeout = const Duration(seconds: 15);

  ApiClient({http.Client? client, SecureStorage? secureStorage}) 
      : _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? SecureStorage();

  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('${AppConfig.backendUrl}$endpoint');
    
    try {
      final headers = await _buildHeaders();
      final response = await _client.get(
        url,
        headers: headers,
      ).timeout(timeout);

      return _processResponse(response);
    } on ApiException {
      rethrow;
    } on SocketException catch (_) {
      throw ApiException('Unable to connect to the SecurePrint server. Please check the backend connection.');
    } on Exception catch (_) {
      throw ApiException('Unable to connect to the SecurePrint server. Please check the backend connection.');
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('${AppConfig.backendUrl}$endpoint');
    
    try {
      final headers = await _buildHeaders();
      final response = await _client.post(
        url,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      ).timeout(timeout);

      return _processResponse(response);
    } on ApiException {
      rethrow;
    } on SocketException catch (_) {
      throw ApiException('Unable to connect to the SecurePrint server. Please check the backend connection.');
    } on Exception catch (_) {
      throw ApiException('Unable to connect to the SecurePrint server. Please check the backend connection.');
    }
  }

  Future<Map<String, String>> _buildHeaders() async {
    final token = await _secureStorage.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<void> downloadFile(String endpoint, String savePath) async {
    final url = Uri.parse('${AppConfig.backendUrl}$endpoint');
    final token = await _secureStorage.getToken();
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final request = http.Request('GET', url);
      request.headers.addAll(headers);
      final response = await _client.send(request).timeout(const Duration(minutes: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final file = File(savePath);
        final sink = file.openWrite();
        await response.stream.pipe(sink);
        await sink.close();
      } else {
        String responseBody = '';
        try {
          responseBody = await response.stream.bytesToString();
        } catch (_) {}
        throw _mapErrorResponse(response.statusCode, responseBody);
      }
    } on ApiException {
      rethrow;
    } on SocketException catch (_) {
      throw ApiException('Unable to connect to the SecurePrint server. Please check the backend connection.');
    } on Exception catch (_) {
      throw ApiException('Unable to connect to the SecurePrint server. Please check the backend connection.');
    }
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        try {
          return json.decode(response.body);
        } catch (e) {
          throw ApiException('Failed to parse response JSON', statusCode: response.statusCode);
        }
      }
      return null;
    } else {
      throw _mapErrorResponse(response.statusCode, response.body);
    }
  }

  ApiException _mapErrorResponse(int statusCode, String body) {
    String? backendDetail;
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
        backendDetail = decoded['detail'].toString();
      }
    } catch (_) {}

    String userMessage;
    switch (statusCode) {
      case 401:
        userMessage = 'Your session has expired. Please log in again.';
        break;
      case 403:
        userMessage = 'You are not authorized to perform this action.';
        break;
      case 404:
        userMessage = 'The requested item could not be found.';
        break;
      case 409:
        userMessage = 'The operation could not be completed because the current state has changed.';
        break;
      case 422:
        userMessage = 'The submitted information is invalid.';
        break;
      case 429:
        userMessage = 'Too many requests. Please try again later.';
        break;
      case 500:
        userMessage = 'SecurePrint server encountered an error.';
        break;
      case 502:
      case 503:
      case 504:
        userMessage = 'SecurePrint server is temporarily unavailable.';
        break;
      default:
        userMessage = backendDetail ?? 'An unexpected error occurred.';
    }

    return ApiException(userMessage, statusCode: statusCode, details: backendDetail);
  }
}
