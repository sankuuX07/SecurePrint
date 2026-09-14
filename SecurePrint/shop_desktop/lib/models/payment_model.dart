class PaymentModel {
  final int id;
  final int printJobId;
  final double amount;
  final String method;
  final String status;
  final String createdAt;
  final String? paidAt;

  PaymentModel({
    required this.id,
    required this.printJobId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as int,
      printJobId: json['print_job_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      method: json['method'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      paidAt: json['paid_at'] as String?,
    );
  }
}
