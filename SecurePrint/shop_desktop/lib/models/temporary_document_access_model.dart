class TemporaryDocumentAccessModel {
  final String id;
  final int printJobId;
  final String documentId;
  final String status;
  final DateTime expiresAt;

  TemporaryDocumentAccessModel({
    required this.id,
    required this.printJobId,
    required this.documentId,
    required this.status,
    required this.expiresAt,
  });

  factory TemporaryDocumentAccessModel.fromJson(Map<String, dynamic> json) {
    return TemporaryDocumentAccessModel(
      id: json['id'] as String,
      printJobId: json['print_job_id'] as int,
      documentId: json['document_id'] as String,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'print_job_id': printJobId,
      'document_id': documentId,
      'status': status,
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}
