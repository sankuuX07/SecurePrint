import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../errors/api_exception.dart';

class ApiClient {
  final http.Client _client = http.Client();
  final Duration timeout = const Duration(seconds: 15);

  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('${AppConfig.backendUrl}$endpoint');
    
    try {
      final response = await _client.get(
        url,
        headers: _buildHeaders(),
      ).timeout(timeout);

      return _processResponse(response);
    } on Exception catch (e) {
      throw ApiException('Network error or timeout: $e');
    }
  }

  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Future: Add Authorization token here
    };
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
