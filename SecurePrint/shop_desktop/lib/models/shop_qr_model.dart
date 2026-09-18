class ShopQrModel {
  final String qrIdentifier;
  final String status;
  final String createdAt;
  final String? revokedAt;

  ShopQrModel({
    required this.qrIdentifier,
    required this.status,
    required this.createdAt,
    this.revokedAt,
  });

  factory ShopQrModel.fromJson(Map<String, dynamic> json) {
    return ShopQrModel(
      qrIdentifier: json['qr_identifier'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      revokedAt: json['revoked_at'] as String?,
    );
  }
}
