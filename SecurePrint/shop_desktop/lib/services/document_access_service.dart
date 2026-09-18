import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/networking/api_client.dart';

class DocumentAccessService {
  final ApiClient _apiClient;

  DocumentAccessService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Downloads the authorized document securely to a temporary file.
  /// Returns the path to the downloaded temporary file.
  Future<String> downloadDocument(String accessId, String originalFilename) async {
    // Determine a safe temporary directory
    final tempDir = await getTemporaryDirectory();
    final safeFilename = _sanitizeFilename(originalFilename);
    // Use a unique name to avoid collisions
    final uniqueFilename = '${DateTime.now().millisecondsSinceEpoch}_$safeFilename';
    final savePath = p.join(tempDir.path, uniqueFilename);

    // Call the download endpoint
    await _apiClient.downloadFile('/api/v1/shop/document-access/$accessId/download', savePath);

    return savePath;
  }

  /// Cleans up a downloaded temporary file
  Future<void> cleanupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Best effort cleanup
      print('Failed to cleanup temporary file: $e');
    }
  }

  String _sanitizeFilename(String filename) {
    // Basic sanitization: remove path traversal elements and invalid characters
    var sanitized = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    sanitized = sanitized.replaceAll('..', '_');
    if (sanitized.isEmpty) {
      sanitized = 'document.pdf';
    }
    return sanitized;
  }
}
