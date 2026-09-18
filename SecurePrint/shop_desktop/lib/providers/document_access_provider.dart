import 'package:flutter/foundation.dart';
import '../models/temporary_document_access_model.dart';
import '../services/shop_service.dart';
import '../services/document_access_service.dart';
import '../errors/api_exception.dart';

enum DocumentAccessState {
  notAuthorized,
  authorizing,
  authorized,
  downloading,
  available,
  expired,
  revoked,
  failed,
}

class DocumentAccessProvider extends ChangeNotifier {
  final ShopService _shopService;
  final DocumentAccessService _documentAccessService;

  DocumentAccessState _state = DocumentAccessState.notAuthorized;
  DocumentAccessState get state => _state;

  TemporaryDocumentAccessModel? _accessModel;
  TemporaryDocumentAccessModel? get accessModel => _accessModel;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _localFilePath;
  String? get localFilePath => _localFilePath;

  DocumentAccessProvider({
    ShopService? shopService,
    DocumentAccessService? documentAccessService,
  })  : _shopService = shopService ?? ShopService(),
        _documentAccessService = documentAccessService ?? DocumentAccessService();

  /// Authorizes access using the secure token from the QR code.
  Future<void> authorize(String qrToken) async {
    _setState(DocumentAccessState.authorizing);
    _errorMessage = null;

    try {
      final responseMap = await _shopService.authorizeDocumentAccess(qrToken);
      _accessModel = TemporaryDocumentAccessModel.fromJson(responseMap);
      
      if (_accessModel!.status == 'active') {
        _setState(DocumentAccessState.authorized);
      } else if (_accessModel!.status == 'expired') {
        _setState(DocumentAccessState.expired);
        _errorMessage = 'Authorization has expired.';
      } else if (_accessModel!.status == 'revoked') {
        _setState(DocumentAccessState.revoked);
        _errorMessage = 'Authorization has been revoked.';
      } else {
        _setState(DocumentAccessState.failed);
        _errorMessage = 'Unknown authorization status: ${_accessModel!.status}';
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
         _setState(DocumentAccessState.failed);
         _errorMessage = 'Session expired. Please log in again.';
      } else if (e.statusCode == 403) {
         _setState(DocumentAccessState.failed);
         _errorMessage = 'Authorization failed. This token might belong to another shop or is invalid.';
      } else if (e.statusCode == 404) {
         _setState(DocumentAccessState.failed);
         _errorMessage = 'Authorization token not found or already used.';
      } else {
         _setState(DocumentAccessState.failed);
         _errorMessage = e.message;
      }
    } catch (e) {
      _setState(DocumentAccessState.failed);
      _errorMessage = 'An unexpected error occurred during authorization: $e';
    }
  }

  /// Downloads the authorized document
  Future<void> downloadDocument(String originalFilename) async {
    if (_state != DocumentAccessState.authorized || _accessModel == null) {
      _setState(DocumentAccessState.failed);
      _errorMessage = 'Cannot download: not authorized.';
      return;
    }

    _setState(DocumentAccessState.downloading);
    _errorMessage = null;

    try {
      _localFilePath = await _documentAccessService.downloadDocument(_accessModel!.id, originalFilename);
      _setState(DocumentAccessState.available);
    } on ApiException catch (e) {
       if (e.statusCode == 401) {
         _setState(DocumentAccessState.failed);
         _errorMessage = 'Session expired. Please log in again.';
      } else if (e.statusCode == 403) {
         _setState(DocumentAccessState.failed);
         _errorMessage = 'Access denied. The authorization may have expired or been revoked.';
      } else if (e.statusCode == 404) {
         _setState(DocumentAccessState.failed);
         _errorMessage = 'The requested document could not be found.';
      } else {
         _setState(DocumentAccessState.failed);
         _errorMessage = e.message;
      }
    } catch (e) {
      _setState(DocumentAccessState.failed);
      _errorMessage = 'Failed to download document: $e';
    }
  }

  /// Resets the state and cleans up temporary files.
  Future<void> reset() async {
    if (_localFilePath != null) {
      await _documentAccessService.cleanupFile(_localFilePath!);
      _localFilePath = null;
    }
    _accessModel = null;
    _errorMessage = null;
    _setState(DocumentAccessState.notAuthorized);
  }

  void _setState(DocumentAccessState newState) {
    _state = newState;
    notifyListeners();
  }
}
