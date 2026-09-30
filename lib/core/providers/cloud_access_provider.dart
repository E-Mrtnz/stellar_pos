import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:stellar_pos/core/cloud/cloud_store_access_service.dart';
import 'package:stellar_pos/core/cloud/store_access_models.dart';
import 'package:stellar_pos/core/cloud/cloud_store_service.dart';

class CloudAccessProvider extends ChangeNotifier {
  final CloudStoreAccessService service;
  final CloudStoreService storeService;

  StoreAccessSnapshot _snapshot = const StoreAccessSnapshot(
    users: [],
    devices: [],
    roles: [],
  );
  bool _loading = false;
  String? _error;

  CloudAccessProvider({
    CloudStoreAccessService? service,
    CloudStoreService? storeService,
  })  : service = service ?? CloudStoreAccessService(),
        storeService = storeService ?? CloudStoreService();

  StoreAccessSnapshot get snapshot => _snapshot;
  bool get isLoading => _loading;
  String? get errorMessage => _error;

  StoreUserRecord? get currentUser {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    for (final user in _snapshot.users) {
      if (user.authUid == uid) return user;
    }
    return null;
  }

  bool hasPermission(String permission) {
    final user = currentUser;

    // Fail closed while the access snapshot is not available. Firestore
    // rules remain the authoritative security boundary, but the client UI
    // should never expose privileged actions merely because access data has
    // not finished loading yet.
    if (user == null) return false;

    if (user.roleId == 'owner') return true;
    if (user.permissionOverrides.containsKey(permission)) {
      return user.permissionOverrides[permission] == true;
    }
    for (final role in _snapshot.roles) {
      if (role.id == user.roleId) return role.permissions.contains(permission);
    }
    for (final role in StoreAccessDefaults.all) {
      if (role.id == user.roleId) return role.permissions.contains(permission);
    }
    return false;
  }

  bool get canManageUsers => hasPermission(StorePermissions.usersManage);

  Future<void> load() async {
    final storeId = await storeService.getStoreId();
    if (storeId == null) {
      _snapshot = const StoreAccessSnapshot(users: [], devices: [], roles: []);
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _snapshot = await service.load(storeId);
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> changeRole(String userId, String roleId) async =>
      _run(() async {
        final storeId = await _requiredStoreId();
        await service.setUserRole(storeId: storeId, userId: userId, roleId: roleId);
      });

  Future<bool> changeStatus(String userId, String status) async =>
      _run(() async {
        final storeId = await _requiredStoreId();
        await service.setUserStatus(storeId: storeId, userId: userId, status: status);
      });

  Future<bool> changePermission(String userId, String permission, bool enabled) async =>
      _run(() async {
        final storeId = await _requiredStoreId();
        await service.setPermissionOverride(
          storeId: storeId,
          userId: userId,
          permission: permission,
          enabled: enabled,
        );
      });

  Future<bool> revokeDevice(String deviceId) async =>
      _run(() async {
        final storeId = await _requiredStoreId();
        await service.revokeDevice(storeId: storeId, deviceId: deviceId);
      });

  Future<String> _requiredStoreId() async =>
      (await storeService.getStoreId()) ??
      (throw StateError('No hay una tienda configurada.'));

  Future<bool> _run(Future<void> Function() action) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      await load();
      return true;
    } catch (error) {
      _error = error.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }
}
