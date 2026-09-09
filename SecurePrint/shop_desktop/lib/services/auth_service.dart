import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

class AuthServiceException implements Exception {
  final String message;
  AuthServiceException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  /// Authenticates a Shop user and returns the JWT access token.
  /// Throws [AuthServiceException] if authentication fails or if the user is not a SHOP.
  Future<String> login(String email, String password) async {
    final url = Uri.parse('${AppConfig.backendUrl}/api/v1/auth/login');
    
    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': email,
          'password': password,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final role = data['role'];
        final token = data['access_token'];

        if (role != 'SHOP') {
          throw AuthServiceException('Access Denied. Shop accounts only.');
        }

        return token;
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        // API returns 400 for incorrect credentials
        final data = jsonDecode(response.body);
        throw AuthServiceException(data['detail'] ?? 'Invalid credentials.');
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        throw AuthServiceException(data['detail'] ?? 'Account unauthorized.');
      } else {
        throw AuthServiceException('Unexpected server error (${response.statusCode}).');
      }
    } catch (e) {
      if (e is AuthServiceException) {
        rethrow;
      }
      throw AuthServiceException('Unable to connect to SecurePrint server.');
    }
  }
}
