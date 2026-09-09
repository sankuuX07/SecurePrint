class PrintJobModel {
  final int id;
  final String status;
  final double price;
  final int copies;
  final String paperSize;
  final String colorMode;
  final String printSide;
  final String? createdAt;
  final int? selectedPageCount;
  final String documentId;

  PrintJobModel({
    required this.id,
    required this.status,
    required this.price,
    required this.copies,
    required this.paperSize,
    required this.colorMode,
    required this.printSide,
    this.createdAt,
    this.selectedPageCount,
    required this.documentId,
  });

  factory PrintJobModel.fromJson(Map<String, dynamic> json) {
    return PrintJobModel(
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
    );
  }
}
