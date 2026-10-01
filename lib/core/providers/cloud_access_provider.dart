import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:stellar_pos/core/cloud/cloud_store_access_service.dart';
import 'package:stellar_pos/core/cloud/store_access_models.dart';
import 'package:stellar_pos/core/cloud/cloud_store_service.dart';

class CloudAccessProvider extends ChangeNotifier {
  final CloudStoreAccessService service;
  final CloudStoreService storeService;
  final FirebaseAuth auth;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _accessSubscription;
  int _accessGeneration = 0;

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
    FirebaseAuth? auth,
  })  : service = service ?? CloudStoreAccessService(),
        storeService = storeService ?? CloudStoreService(),
        auth = auth ?? FirebaseAuth.instance {
    _authSubscription = this.auth.authStateChanges().listen(_handleAuthChanged);
  }

  StoreAccessSnapshot get snapshot => _snapshot;
  bool get isLoading => _loading;
  bool get accessResolved => _accessResolved;
  String? get errorMessage => _error;

  StoreUserRecord? get currentUser {
    final uid = auth.currentUser?.uid;
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

  bool get hasStoreAccess => _accessResolved && currentUser != null && currentUser!.isActive;

  bool get canManageUsers => hasPermission(StorePermissions.usersManage);

  Future<void> load() async {
    final storeId = await storeService.getStoreId();
    await loadForStore(storeId, force: true);
  }

  /// Loads access whenever the active store changes. This is important after
  /// joining a store because this provider is created before the store
  /// identity is available during application startup.
  Future<void> loadForStore(String? storeId, {bool force = false}) async {
    await _cancelAccessListener();
    final generation = ++_accessGeneration;
    final normalizedStoreId = storeId?.trim();
    if (normalizedStoreId == null || normalizedStoreId.isEmpty) {
      await _cancelAccessListener();
      ++_accessGeneration;
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
      final user = auth.currentUser;
      if (user == null) {
        _snapshot = const StoreAccessSnapshot(users: [], devices: [], roles: []);
        return;
      }

      _snapshot = await service.load(normalizedStoreId);
      if (generation == _accessGeneration) {
        _startAccessListener(normalizedStoreId, generation);
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      // Access is a UI state; Firestore rules remain the security boundary.
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

  Future<void> _handleAuthChanged(User? user) async {
    if (user == null) {
      await _cancelAccessListener();
      ++_accessGeneration;
      _loadedStoreId = null;
      _snapshot = const StoreAccessSnapshot(users: [], devices: [], roles: []);
      _accessResolved = true;
      _loading = false;
      notifyListeners();
      return;
    }

    final storeId = await storeService.getStoreId();
    if (storeId != null && storeId.isNotEmpty) {
      await loadForStore(storeId, force: true);
    }
  }

  void _startAccessListener(String storeId, int generation) {
    _accessSubscription?.cancel();
    _accessSubscription = service.watchCurrentUser(storeId).listen(
      (document) => _handleAccessDocument(
        storeId,
        generation,
        document,
      ),
      onError: (Object error) {
        if (generation != _accessGeneration) return;
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> _handleAccessDocument(
    String storeId,
    int generation,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    if (generation != _accessGeneration) return;

    if (!document.exists || document.data() == null) {
      _snapshot = const StoreAccessSnapshot(
        users: [],
        devices: [],
        roles: [],
      );
      _accessResolved = true;
      notifyListeners();
      return;
    }

    final current = StoreUserRecord.fromFirestore(
      document.id,
      document.data()!,
    );
    final previous = currentUser;
    final privilegeBoundaryChanged = previous == null ||
        previous.roleId != current.roleId ||
        previous.status != current.status;

    if (privilegeBoundaryChanged) {
      _accessResolved = false;
      notifyListeners();
      try {
        final refreshed = await service.load(storeId);
        if (generation != _accessGeneration) return;
        _snapshot = refreshed;
        _error = null;
      } catch (error) {
        if (generation != _accessGeneration) return;
        _error = error.toString();
      } finally {
        if (generation == _accessGeneration) {
          _accessResolved = true;
          notifyListeners();
        }
      }
      return;
    }

    _replaceCurrentUser(current);
    _error = null;
    _accessResolved = true;
    notifyListeners();
  }

  void _replaceCurrentUser(StoreUserRecord user) {
    final users = List<StoreUserRecord>.from(_snapshot.users);
    final index = users.indexWhere((item) => item.authUid == user.authUid);
    if (index < 0) {
      _snapshot = StoreAccessSnapshot(
        users: <StoreUserRecord>[...users, user],
        devices: _snapshot.devices,
        roles: _snapshot.roles,
      );
      return;
    }
    users[index] = user;
    _snapshot = StoreAccessSnapshot(
      users: users,
      devices: _snapshot.devices,
      roles: _snapshot.roles,
    );
  }

  Future<void> _cancelAccessListener() async {
    final subscription = _accessSubscription;
    _accessSubscription = null;
    await subscription?.cancel();
  }

  @override
  void dispose() {
    _accessSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<bool> deleteUser(String userId) async {
    final target = _userById(userId);
    final currentUid = auth.currentUser?.uid;
    if (target == null) return false;
    if (target.roleId == 'owner') {
      _error = 'El propietario de la tienda no se puede eliminar.';
      notifyListeners();
      return false;
    }
    if (target.authUid == currentUid) {
      _error = 'No puedes eliminar tu propia cuenta desde esta pantalla.';
      notifyListeners();
      return false;
    }

    final previousUsers = _snapshot.users;
    final previousDevices = _snapshot.devices;
    final nextUsers = previousUsers.where((user) => user.userId != userId).toList(growable: false);
    final nextDevices = previousDevices.where((device) => device.userId != userId).toList(growable: false);
    _snapshot = StoreAccessSnapshot(
      users: nextUsers,
      devices: nextDevices,
      roles: _snapshot.roles,
    );
    notifyListeners();

    return _runMutation(
      () async {
        final storeId = await _requiredStoreId();
        await service.deleteUser(storeId: storeId, userId: userId);
      },
      rollback: () {
        _snapshot = StoreAccessSnapshot(
          users: previousUsers,
          devices: previousDevices,
          roles: _snapshot.roles,
        );
        notifyListeners();
      },
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
