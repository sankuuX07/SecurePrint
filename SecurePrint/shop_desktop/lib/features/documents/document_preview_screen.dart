import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../models/print_job_detail_model.dart';
import '../../providers/document_access_provider.dart';
import 'package:provider/provider.dart';

class DocumentPreviewScreen extends StatefulWidget {
  final PrintJobDetailModel job;
  final String localFilePath;

  const DocumentPreviewScreen({
    Key? key,
    required this.job,
    required this.localFilePath,
  }) : super(key: key);

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  PdfViewerController? _pdfViewerController;
  
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfViewerController?.dispose();
    // In M7/M8 we clean up the file when preview is closed to avoid leaving documents behind.
    // Ensure the DocumentAccessProvider cleans up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DocumentAccessProvider>().reset();
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Preview - Job #${widget.job.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              _pdfViewerController?.zoomLevel = (_pdfViewerController?.zoomLevel ?? 1.0) + 0.5;
            },
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              _pdfViewerController?.zoomLevel = (_pdfViewerController?.zoomLevel ?? 1.0) - 0.5;
            },
            tooltip: 'Zoom Out',
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar with Job Details
          Container(
            width: 300,
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Print Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildDetailRow('Copies', widget.job.copies.toString()),
                  _buildDetailRow('Paper Size', widget.job.paperSize),
                  _buildDetailRow('Color Mode', widget.job.colorMode),
                  _buildDetailRow('Print Side', widget.job.printSide),
                  if (widget.job.selectedPageCount != null)
                    _buildDetailRow('Pages Selected', widget.job.selectedPageCount.toString()),
                  const SizedBox(height: 24),
                  const Text('Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildDetailRow('Job Status', widget.job.status),
                  _buildDetailRow('Price', '\$${widget.job.price.toStringAsFixed(2)}'),
                  
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Printing functionality will be available in M9.')),
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text('Print Document'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // PDF Viewer
          Expanded(
            child: _hasError
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage.isNotEmpty ? _errorMessage : 'Failed to load preview for this document.',
                          style: const TextStyle(fontSize: 18, color: Colors.red),
                        ),
                      ],
                    ),
                  )
                : SfPdfViewer.file(
                    File(widget.localFilePath),
                    key: _pdfViewerKey,
                    controller: _pdfViewerController,
                    canShowScrollHead: false,
                    canShowScrollStatus: true,
                    onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                      setState(() {
                        _hasError = true;
                        _errorMessage = 'Could not load PDF: ${details.description}';
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
