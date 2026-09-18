import 'package:flutter/material.dart';
import '../services/shop_service.dart';
import '../models/shop_qr_model.dart';
import '../core/errors/api_exception.dart';

enum ShopQrState {
  initial,
  loading,
  loaded,
  error,
}

class ShopQrProvider extends ChangeNotifier {
  final ShopService _shopService;
  
  ShopQrState _state = ShopQrState.initial;
  String? _errorMessage;
  ShopQrModel? _shopQr;
  bool _isRegenerating = false;

  ShopQrProvider({ShopService? shopService}) 
      : _shopService = shopService ?? ShopService();

  ShopQrState get state => _state;
  String? get errorMessage => _errorMessage;
  ShopQrModel? get shopQr => _shopQr;
  bool get isRegenerating => _isRegenerating;

  Future<void> loadQr() async {
    _state = ShopQrState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _shopQr = await _shopService.getShopQr();
      _state = ShopQrState.loaded;
    } on ApiException catch (e) {
      _state = ShopQrState.error;
      _errorMessage = e.message;
    } catch (e) {
      _state = ShopQrState.error;
      _errorMessage = 'An unexpected error occurred while loading QR.';
    }
    
    notifyListeners();
  }

  Future<void> regenerateQr() async {
    if (_isRegenerating) return;
    
    _isRegenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _shopQr = await _shopService.regenerateShopQr();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to regenerate QR.';
    } finally {
      _isRegenerating = false;
      notifyListeners();
    }
  }
}
