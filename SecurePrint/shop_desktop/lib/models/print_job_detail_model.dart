import 'print_job_model.dart';

class PrintJobStatusHistoryModel {
  final int id;
  final String? fromStatus;
  final String toStatus;
  final String changedAt;
  final String? notes;

  PrintJobStatusHistoryModel({
    required this.id,
    this.fromStatus,
    required this.toStatus,
    required this.changedAt,
    this.notes,
  });

  factory PrintJobStatusHistoryModel.fromJson(Map<String, dynamic> json) {
    return PrintJobStatusHistoryModel(
      id: json['id'] as int,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String,
      changedAt: json['changed_at'] as String,
      notes: json['notes'] as String?,
    );
  }
}

class PrintJobDetailModel extends PrintJobModel {
  final List<PrintJobStatusHistoryModel> statusHistory;

  PrintJobDetailModel({
    required super.id,
    required super.status,
    required super.price,
    required super.copies,
    required super.paperSize,
    required super.colorMode,
    required super.printSide,
    super.createdAt,
    super.selectedPageCount,
    required super.documentId,
    required this.statusHistory,
  });

  factory PrintJobDetailModel.fromJson(Map<String, dynamic> json) {
    final historyList = (json['status_history'] as List<dynamic>?)
            ?.map((e) => PrintJobStatusHistoryModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return PrintJobDetailModel(
      id: json['id'] as int,
      status: json['status'] as String,
      price: (json['price'] as num).toDouble(),
      copies: json['copies'] as int,
      paperSize: json['paper_size'] as String,
      colorMode: json['color_mode'] as String,
      printSide: json['print_side'] as String,
      createdAt: json['created_at'] as String?,
      selectedPageCount: json['selected_page_count'] as int?,
      documentId: json['document_id'] as String,
      statusHistory: historyList,
    );
  }
}
