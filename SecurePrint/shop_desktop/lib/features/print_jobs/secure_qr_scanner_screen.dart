import 'package:flutter/material.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_access_provider.dart';
import '../../models/print_job_detail_model.dart';
import '../documents/document_preview_screen.dart';

class SecureQrScannerScreen extends StatefulWidget {
  final PrintJobDetailModel job;
  
  const SecureQrScannerScreen({Key? key, required this.job}) : super(key: key);

  @override
  State<SecureQrScannerScreen> createState() => _SecureQrScannerScreenState();
}
class _SecureQrScannerScreenState extends State<SecureQrScannerScreen> {
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentAccessProvider>().reset();
    });
  }

  Future<void> _handleScan(String? token) async {
    if (token == null || token.isEmpty || token == '-1') {
      return; // Canceled or failed to scan
    }
    
    setState(() {
      _isScanning = false;
    });

    final provider = context.read<DocumentAccessProvider>();
    await provider.authorize(token);

    if (provider.state == DocumentAccessState.authorized) {
      await provider.downloadDocument('document_${widget.job.id}.pdf');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentAccessProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Secure Print QR'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Ask the customer to display the Secure Print Access QR.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          
          if (provider.state == DocumentAccessState.notAuthorized && _isScanning)
            Expanded(
              child: SimpleBarcodeScannerPage(
                onResult: (result) {
                  _handleScan(result);
                },
              ),
            ),
            
          if (!_isScanning)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (provider.state == DocumentAccessState.authorizing) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Authorizing...', style: TextStyle(fontSize: 18)),
                    ],
                    
                    if (provider.state == DocumentAccessState.authorized || provider.state == DocumentAccessState.downloading) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Authorized. Downloading document securely...', style: TextStyle(fontSize: 18)),
                    ],

                    if (provider.state == DocumentAccessState.available) ...[
                      const Icon(Icons.check_circle, color: Colors.green, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Document access authorized and ready.',
                        style: TextStyle(fontSize: 18, color: Colors.green),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => DocumentPreviewScreen(
                                job: widget.job,
                                localFilePath: provider.localFilePath!,
                              ),
                            ),
                          );
                        },
                        child: const Text('Open Document'),
                      ),
                    ],
                      
                    if (provider.state == DocumentAccessState.failed || provider.state == DocumentAccessState.expired || provider.state == DocumentAccessState.revoked) ...[
                      const Icon(Icons.error_outline, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        provider.errorMessage ?? 'Authorization failed.',
                        style: const TextStyle(fontSize: 18, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isScanning = true;
                          });
                          provider.reset();
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
