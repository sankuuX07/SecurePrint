import 'package:flutter/material.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:provider/provider.dart';
import '../../services/shop_service.dart';
import '../../core/errors/api_exception.dart';
import '../../providers/auth_provider.dart';

class SecureQrScannerScreen extends StatefulWidget {
  final int jobId;
  
  const SecureQrScannerScreen({Key? key, required this.jobId}) : super(key: key);

  @override
  State<SecureQrScannerScreen> createState() => _SecureQrScannerScreenState();
}

class _SecureQrScannerScreenState extends State<SecureQrScannerScreen> {
  bool _isProcessing = false;
  String? _statusMessage;
  bool _isSuccess = false;
  String? _accessId;

  Future<void> _handleScan(String? token) async {
    if (token == null || token.isEmpty || token == '-1') {
      return; // Canceled or failed to scan
    }
    if (_isProcessing || _isSuccess) return; // Debounce

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Authorizing...';
    });

    try {
      final shopService = Provider.of<ShopService>(context, listen: false);
      final response = await shopService.authorizeDocumentAccess(token);
      
      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _accessId = response['access_id'];
        _statusMessage = 'Document access authorized.';
      });
      
    } on ApiException catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
      });
      
      if (e.statusCode == 401) {
        context.read<AuthProvider>().logout();
      } else {
        String msg = 'Authorization failed.';
        if (e.message.contains('invalid or unavailable')) {
          msg = 'Invalid or expired Secure Access QR.';
        } else {
          msg = e.message;
        }
        
        setState(() {
          _statusMessage = msg;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = 'An unexpected error occurred.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          
          if (!_isProcessing && !_isSuccess && _statusMessage == null)
            Expanded(
              child: SimpleBarcodeScannerPage(
                onResult: (result) {
                  _handleScan(result);
                },
              ),
            ),
            
          if (_isProcessing || _isSuccess || _statusMessage != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessing) 
                      const CircularProgressIndicator(),
                    
                    if (_isSuccess)
                      const Icon(Icons.check_circle, color: Colors.green, size: 64),
                      
                    if (!_isSuccess && !_isProcessing && _statusMessage != null)
                      const Icon(Icons.error_outline, color: Colors.red, size: 64),
                      
                    const SizedBox(height: 24),
                    
                    if (_statusMessage != null)
                      Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 18, 
                          color: _isSuccess ? Colors.green : Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                    const SizedBox(height: 24),
                    
                    if (_isSuccess)
                      ElevatedButton(
                        onPressed: () {
                          // M7 placeholder
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Document access will be available in the next module.')),
                          );
                          Navigator.of(context).pop();
                        },
                        child: const Text('Continue to Document'),
                      ),
                      
                    if (!_isSuccess && !_isProcessing)
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _statusMessage = null;
                          });
                        },
                        child: const Text('Try Again'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
