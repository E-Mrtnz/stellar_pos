import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/cloud/cloud_store_service.dart';

/// Application state for the store identity used by Stellar POS.
///
/// The visible name is editable. The internal store id is immutable and is
/// generated when the store is created in Firestore.
class CloudStoreProvider extends ChangeNotifier {
  final CloudStoreService _service;

  String? _storeId;
  String? _storeName;
  String? _inviteCode;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  CloudStoreProvider({CloudStoreService? service})
      : _service = service ?? CloudStoreService();

  String? get storeId => _storeId;
  String? get storeName => _storeName;
  String? get inviteCode => _inviteCode;
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
      _storeName = await _service.getStoreName();
      _inviteCode = await _service.getInviteCode();
    } catch (error) {
      _errorMessage = _friendlyError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createStore(String storeName) async {
    return _run(() async {
      await _service.createStore(storeName);
      await _reloadIdentity();
    });
  }

  Future<bool> joinStore(String invitationCode) async {
    return _run(() async {
      await _service.joinStore(invitationCode);
      await _reloadIdentity();
    });
  }

  Future<bool> renameStore(String storeName) async {
    return _run(() async {
      await _service.renameStore(storeName);
      _storeName = await _service.getStoreName();
    });
  }

  Future<bool> rotateInviteCode() async {
    return _run(() async {
      await _service.rotateInviteCode();
      _inviteCode = await _service.getInviteCode();
    });
  }

  Future<bool> sync() async {
    return _run(() => _service.sync());
  }

  Future<void> clear() async {
    if (_isSaving) return;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.identityStore.clearStore();
      _storeId = null;
      _storeName = null;
      _inviteCode = null;
    } catch (error) {
      _errorMessage = _friendlyError(error);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> _run(Future<void> Function() operation) async {
    if (_isSaving) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await operation();
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _reloadIdentity() async {
    _storeId = await _service.getStoreId();
    _storeName = await _service.getStoreName();
    _inviteCode = await _service.getInviteCode();
  }

  String _friendlyError(Object error) {
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst(
            RegExp(r'^(Bad state|Invalid argument).*?: '),
            '',
          );
    }
    return error.toString();
  }
}
