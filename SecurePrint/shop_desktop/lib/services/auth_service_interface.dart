import '../models/user_model.dart';

/// Result object returned by authentication services.
class AuthResult {
  final String token;
  final String role;
  final UserModel? user;
  final bool isLocal;

  AuthResult({
    required this.token,
    required this.role,
    this.user,
    this.isLocal = false,
  });
}

/// Registration payload for creating a Shop account.
class ShopRegistrationData {
  final String ownerName;
  final String shopName;
  final String email;
  final String phone;
  final String password;
  final String address;
  final String city;

  ShopRegistrationData({
    required this.ownerName,
    required this.shopName,
    required this.email,
    required this.phone,
    required this.password,
    required this.address,
    required this.city,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': ownerName,
      'shop_name': shopName,
      'email': email,
      'phone': phone,
      'password': password,
      'address': address,
      'city': city,
      'role': 'SHOP',
    };
  }
}

/// Standard interface for authentication providers (local test & production backend).
abstract class IAuthService {
  /// Authenticates a user with email and password.
  Future<AuthResult> login(String email, String password);

  /// Registers a new shop account.
  Future<void> register(ShopRegistrationData data);
}
