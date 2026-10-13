import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import 'auth_service.dart';
import 'auth_service_interface.dart';

/// Production backend authentication service connecting to FastAPI endpoints.
class BackendAuthService implements IAuthService {
  final AuthService _authService;
  final http.Client _client;

  BackendAuthService({AuthService? authService, http.Client? client})
      : _client = client ?? http.Client(),
        _authService = authService ?? AuthService(client: client);

  @override
  Future<AuthResult> login(String email, String password) async {
    final token = await _authService.login(email, password);
    return AuthResult(
      token: token,
      role: 'SHOP',
      isLocal: false,
    );
  }

  @override
  Future<void> register(ShopRegistrationData data) async {
    final baseUrl = AppConfig.backendUrl.trim();
    if (baseUrl.isEmpty) {
      throw AuthServiceException('Backend URL is not configured. Please check connection settings.');
    }
    final url = Uri.parse('$baseUrl/api/v1/auth/register');

    final payload = {
      'name': data.ownerName,
      'email': data.email,
      'phone': data.phone,
      'role': 'SHOP',
      'shop_name': data.shopName,
      'address': data.address,
      'city': data.city,
      'password': data.password,
      'pricing': {
        'price_a4_bw_single': 1.0,
        'price_a4_bw_double': 1.5,
        'price_a4_color_single': 5.0,
        'price_a4_color_double': 8.0,
        'price_a3_bw_single': 2.0,
        'price_a3_bw_double': 3.0,
        'price_a3_color_single': 10.0,
        'price_a3_color_double': 15.0,
      },
    };

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        throw AuthServiceException(errorData['detail'] ?? 'Registration failed.');
      } else {
        throw AuthServiceException('Server returned error code ${response.statusCode}.');
      }
    } catch (e) {
      if (e is AuthServiceException) rethrow;
      throw AuthServiceException('Unable to connect to SecurePrint server.');
    }
  }
}
