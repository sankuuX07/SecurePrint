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
    } on Exception catch (e) {
      throw ApiException('Network error or timeout: $e');
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
    } on Exception catch (e) {
      throw ApiException('Network error or timeout: $e');
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
        String errorMessage = 'Failed to download file';
        try {
          final responseBody = await response.stream.bytesToString();
          final decoded = json.decode(responseBody);
          if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
            errorMessage = decoded['detail'].toString();
          }
        } catch (_) {}
        throw ApiException(errorMessage, statusCode: response.statusCode);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error or timeout: $e');
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
      String errorMessage = 'Unknown error';
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
          errorMessage = decoded['detail'].toString();
        }
      } catch (_) {
        errorMessage = response.body;
      }
      throw ApiException(errorMessage, statusCode: response.statusCode);
    }
  }
}
