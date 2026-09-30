import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/cloud/cloud_store_service.dart';

/// Application state for the currently selected cloud store/tenant.
///
/// The provider does not choose a store automatically. A store must be
/// explicitly configured by the application settings or account flow.
class CloudStoreProvider extends ChangeNotifier {
  final CloudStoreService _service;

  String? _storeId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  CloudStoreProvider({CloudStoreService? service})
      : _service = service ?? CloudStoreService();

  String? get storeId => _storeId;
  bool get isConfigured => _storeId != null && _storeId!.isNotEmpty;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _storeId = await _service.getStoreId();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> configure(String storeId) async {
    if (_isSaving) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.configureStore(storeId);
      _storeId = await _service.getStoreId();
      return true;
    } catch (error) {
      _errorMessage = error is StateError
          ? error.message
          : error is ArgumentError
          ? error.message
          : error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    if (_isSaving) return;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.clearStore();
      _storeId = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
