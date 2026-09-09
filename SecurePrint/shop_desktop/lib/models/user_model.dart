class UserModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? shopName;
  final String? address;
  final String? city;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.shopName,
    this.address,
    this.city,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      shopName: json['shop_name'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
    );
  }
}
