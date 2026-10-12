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
    final rawId = json['access_id'] ?? json['id'];
    if (rawId == null || rawId.toString().trim().isEmpty) {
      throw const FormatException('Missing access identifier in authorization response');
    }

    final rawJobId = json['print_job_id'];
    if (rawJobId == null) {
      throw const FormatException('Missing print_job_id in authorization response');
    }
    final parsedJobId = rawJobId is int ? rawJobId : int.parse(rawJobId.toString());

    final rawDocId = json['document_id'];
    if (rawDocId == null || rawDocId.toString().trim().isEmpty) {
      throw const FormatException('Missing document_id in authorization response');
    }

    final rawStatus = json['status'];
    if (rawStatus == null || rawStatus.toString().trim().isEmpty) {
      throw const FormatException('Missing status in authorization response');
    }

    final rawExpiresAt = json['expires_at'];
    if (rawExpiresAt == null) {
      throw const FormatException('Missing expires_at in authorization response');
    }
    final parsedExpiresAt = rawExpiresAt is DateTime
        ? rawExpiresAt
        : DateTime.parse(rawExpiresAt.toString());

    return TemporaryDocumentAccessModel(
      id: rawId.toString(),
      printJobId: parsedJobId,
      documentId: rawDocId.toString(),
      status: rawStatus.toString(),
      expiresAt: parsedExpiresAt,
    );
  }

  bool get isAuthorized {
    final s = status.toUpperCase();
    return s == 'AUTHORIZED' || s == 'ACTIVE';
  }

  bool get isExpired {
    final s = status.toUpperCase();
    return s == 'EXPIRED' || DateTime.now().toUtc().isAfter(expiresAt.toUtc());
  }

  bool get isRevoked => status.toUpperCase() == 'REVOKED';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'access_id': id,
      'print_job_id': printJobId,
      'document_id': documentId,
      'status': status,
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}
