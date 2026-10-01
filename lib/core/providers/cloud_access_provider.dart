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
  bool _accessResolved = false;
  String? _error;
  String? _loadedStoreId;

  CloudAccessProvider({
    CloudStoreAccessService? service,
    CloudStoreService? storeService,
  })  : service = service ?? CloudStoreAccessService(),
        storeService = storeService ?? CloudStoreService();

  StoreAccessSnapshot get snapshot => _snapshot;
  bool get isLoading => _loading;
  bool get accessResolved => _accessResolved;
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

    // Cloud access controls are not the security boundary; Firestore rules
    // are. The POS is local-first, so a temporary Auth/access loading failure
    // must not blank the entire application. Until the access snapshot is
    // resolved, keep the local UI available. Once a valid user record is
    // loaded, enforce that user's permissions normally.
    if (!_accessResolved || _loadedStoreId == null) return true;
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
    await loadForStore(storeId, force: true);
  }

  /// Loads access whenever the active store changes. This is important after
  /// joining a store because this provider is created before the store
  /// identity is available during application startup.
  Future<void> loadForStore(String? storeId, {bool force = false}) async {
    final normalizedStoreId = storeId?.trim();
    if (normalizedStoreId == null || normalizedStoreId.isEmpty) {
      _loadedStoreId = null;
      _snapshot = const StoreAccessSnapshot(users: [], devices: [], roles: []);
      _accessResolved = true;
      notifyListeners();
      return;
    }
    if (!force && _loadedStoreId == normalizedStoreId && _accessResolved) return;
    _loadedStoreId = normalizedStoreId;
    _accessResolved = false;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // On Web, Firebase Auth can still be restoring its persisted anonymous
      // session when this provider is created. Wait for that first auth event
      // before loading the store access document; otherwise currentUser can be
      // null temporarily and the sidebar fails closed with no navigation.
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        user = await FirebaseAuth.instance.authStateChanges().first;
      }
      if (user == null) {
        user = (await FirebaseAuth.instance.signInAnonymously()).user;
      }
      if (user == null) {
        throw StateError('Firebase Authentication no devolvió un usuario.');
      }

      _snapshot = await service.load(normalizedStoreId);
    } catch (error) {
      _error = error.toString();
    } finally {
      // A failed/anonymous access lookup must remain non-blocking for the
      // local-first POS. Firestore itself still enforces the real permissions.
      _accessResolved = true;
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> changeRole(String userId, String roleId) async {
    final previous = _userById(userId);
    if (previous == null) return false;
    final optimistic = previous.copyWith(roleId: roleId);
    _replaceUser(optimistic);
    return _runMutation(
      () async {
        final storeId = await _requiredStoreId();
        await service.setUserRole(
          storeId: storeId,
          userId: userId,
          roleId: roleId,
        );
      },
      rollback: () => _replaceUser(previous, notify: true),
    );
  }

  Future<bool> changeStatus(String userId, String status) async {
    final previous = _userById(userId);
    if (previous == null) return false;
    final optimistic = previous.copyWith(status: status);
    _replaceUser(optimistic);
    return _runMutation(
      () async {
        final storeId = await _requiredStoreId();
        await service.setUserStatus(
          storeId: storeId,
          userId: userId,
          status: status,
        );
      },
      rollback: () => _replaceUser(previous, notify: true),
    );
  }

  Future<bool> changePermission(
    String userId,
    String permission,
    bool enabled,
  ) async {
    final previous = _userById(userId);
    if (previous == null) return false;
    final overrides = Map<String, bool>.from(previous.permissionOverrides)
      ..[permission] = enabled;
    final optimistic = previous.copyWith(permissionOverrides: overrides);
    _replaceUser(optimistic);
    return _runMutation(
      () async {
        final storeId = await _requiredStoreId();
        await service.setPermissionOverride(
          storeId: storeId,
          userId: userId,
          permission: permission,
          enabled: enabled,
        );
      },
      rollback: () => _replaceUser(previous, notify: true),
    );
  }

  Future<bool> resetPermission(String userId, String permission) async {
    final previous = _userById(userId);
    if (previous == null) return false;
    final overrides = Map<String, bool>.from(previous.permissionOverrides)
      ..remove(permission);
    final optimistic = previous.copyWith(permissionOverrides: overrides);
    _replaceUser(optimistic);
    return _runMutation(
      () async {
        final storeId = await _requiredStoreId();
        await service.clearPermissionOverride(
          storeId: storeId,
          userId: userId,
          permission: permission,
        );
      },
      rollback: () => _replaceUser(previous, notify: true),
    );
  }

  Future<bool> revokeDevice(String deviceId) async {
    StoreDeviceRecord? previous;
    for (final device in _snapshot.devices) {
      if (device.deviceId == deviceId) {
        previous = device;
        break;
      }
    }
    if (previous == null) return false;

    _replaceDevice(previous.copyWith(active: false), notify: true);
    return _runMutation(
      () async {
        final storeId = await _requiredStoreId();
        await service.revokeDevice(
          storeId: storeId,
          deviceId: deviceId,
        );
      },
      rollback: () => _replaceDevice(previous!, notify: true),
    );
  }

  Future<String> _requiredStoreId() async =>
      (await storeService.getStoreId()) ??
      (throw StateError('No hay una tienda configurada.'));

  StoreUserRecord? _userById(String userId) {
    for (final user in _snapshot.users) {
      if (user.userId == userId) return user;
    }
    return null;
  }

  void _replaceUser(StoreUserRecord user, {bool notify = true}) {
    final users = List<StoreUserRecord>.from(_snapshot.users);
    final index = users.indexWhere((item) => item.userId == user.userId);
    if (index < 0) return;
    users[index] = user;
    _snapshot = StoreAccessSnapshot(
      users: users,
      devices: _snapshot.devices,
      roles: _snapshot.roles,
    );
    if (notify) notifyListeners();
  }

  void _replaceDevice(StoreDeviceRecord device, {bool notify = true}) {
    final devices = List<StoreDeviceRecord>.from(_snapshot.devices);
    final index = devices.indexWhere((item) => item.deviceId == device.deviceId);
    if (index < 0) return;
    devices[index] = device;
    _snapshot = StoreAccessSnapshot(
      users: _snapshot.users,
      devices: devices,
      roles: _snapshot.roles,
    );
    if (notify) notifyListeners();
  }

  Future<bool> _runMutation(
    Future<void> Function() action, {
    required VoidCallback rollback,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      _error = error.toString();
      rollback();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
