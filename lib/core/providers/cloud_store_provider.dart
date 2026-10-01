import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/cloud/cloud_store_service.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_engine.dart';

/// Application state for the store identity used by Stellar POS.
///
/// The visible name is editable. The internal store id is immutable and is
/// generated when the store is created in Firestore.
class CloudStoreProvider extends ChangeNotifier {
  final CloudStoreService _service;

  String? _storeId;
  String? _storeName;
  String? _inviteCode;
  String? _ownerEmail;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  CloudSyncResult? _lastSyncResult;

  CloudStoreProvider({CloudStoreService? service})
      : _service = service ?? CloudStoreService();

  String? get storeId => _storeId;
  String? get storeName => _storeName;
  String? get inviteCode => _inviteCode;
  String? get ownerEmail => _ownerEmail;
  bool get isConfigured => _storeId != null && _storeId!.isNotEmpty;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  CloudSyncResult? get lastSyncResult => _lastSyncResult;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _storeId = await _service.getStoreId();
      _storeName = await _service.getStoreName();
      _inviteCode = await _service.getInviteCode();
      _ownerEmail = await _service.getOwnerEmail();
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

  Future<bool> joinStore(String displayName, String invitationCode) async {
    return _run(() async {
      await _service.joinStore(displayName, invitationCode);
      await _reloadIdentity();
    });
  }

  Future<bool> updateOwnerEmail(String ownerEmail) async {
    return _run(() async {
      await _service.updateOwnerEmail(ownerEmail);
      _ownerEmail = await _service.getOwnerEmail();
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
      _ownerEmail = await _service.getOwnerEmail();
    });
  }

  Future<bool> sync() async {
    return _run(() async {
      _lastSyncResult = await _service.sync();
    });
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
      _ownerEmail = null;
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
    final message = error.toString();
    if (message.contains('permission-denied') ||
        message.contains('The caller does not have permission')) {
      return 'Firebase rechazó esta operación por las reglas de seguridad de Firestore. '
          'La aplicación sí está autenticada; hay que publicar las reglas de Firestore '
          'del proyecto stellar-pos-8384a.';
    }
    return message;
  }
}
