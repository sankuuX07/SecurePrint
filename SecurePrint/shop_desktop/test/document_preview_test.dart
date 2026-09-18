import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shop_desktop/features/documents/document_preview_screen.dart';
import 'package:shop_desktop/models/print_job_detail_model.dart';
import 'package:shop_desktop/providers/document_access_provider.dart';
import 'package:shop_desktop/services/document_access_service.dart';

void main() {
  testWidgets('DocumentPreviewScreen displays job details', (WidgetTester tester) async {
    final mockJob = PrintJobDetailModel(
      id: 123,
      status: 'ACCEPTED',
      price: 15.50,
      copies: 5,
      paperSize: 'A4',
      colorMode: 'COLOR',
      printSide: 'DOUBLE',
      documentId: 'doc_1',
      statusHistory: [],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DocumentAccessProvider>(
            create: (_) => DocumentAccessProvider(documentAccessService: DocumentAccessService()),
          ),
        ],
        child: MaterialApp(
          home: DocumentPreviewScreen(
            job: mockJob,
            localFilePath: 'dummy_path.pdf',
          ),
        ),
      ),
    );

    // Initial load will try to load the dummy path and fail gracefully showing error message in SfPdfViewer
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Document Preview - Job #123'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // Copies
    expect(find.text('A4'), findsOneWidget); // Paper Size
    expect(find.text('COLOR'), findsOneWidget); // Color Mode
    expect(find.text('DOUBLE'), findsOneWidget); // Print Side
    expect(find.text('\$15.50'), findsOneWidget); // Price
  });
}
