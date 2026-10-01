import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:stellar_pos/core/cloud/cloud_collection.dart';
import 'package:stellar_pos/core/cloud/device_registry_service.dart';
import 'package:stellar_pos/core/cloud/store_access_models.dart';

class CloudStoreAccessService {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final DeviceRegistryService deviceRegistry;

  CloudStoreAccessService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DeviceRegistryService? deviceRegistry,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance,
        deviceRegistry = deviceRegistry ?? DeviceRegistryService();

  CollectionReference<Map<String, dynamic>> _users(String storeId) =>
      firestore.collection(CloudCollection.stores).doc(storeId).collection('users');

  CollectionReference<Map<String, dynamic>> _devices(String storeId) =>
      firestore.collection(CloudCollection.stores).doc(storeId).collection('devices');

  CollectionReference<Map<String, dynamic>> _roles(String storeId) =>
      firestore.collection(CloudCollection.stores).doc(storeId).collection('roles');

  Future<StoreAccessSnapshot> load(String storeId) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      return const StoreAccessSnapshot(users: [], devices: [], roles: []);
    }

    final currentUserDoc = await _users(storeId).doc(uid).get();
    if (!currentUserDoc.exists) {
      return const StoreAccessSnapshot(users: [], devices: [], roles: []);
    }

    final currentUser =
        StoreUserRecord.fromFirestore(currentUserDoc.id, currentUserDoc.data()!);
    final canManage =
        currentUser.roleId == 'owner' || currentUser.roleId == 'administrator';

    if (!canManage) {
      return StoreAccessSnapshot(
        users: [currentUser],
        devices: const [],
        roles: StoreAccessDefaults.all,
      );
    }

    final results = await Future.wait([
      _users(storeId).orderBy('createdAt').get(),
      _devices(storeId).orderBy('lastSeenAt', descending: true).get(),
      _roles(storeId).get(),
    ]);

    final users = (results[0] as QuerySnapshot<Map<String, dynamic>>)
        .docs
        .map((doc) => StoreUserRecord.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
    final devices = (results[1] as QuerySnapshot<Map<String, dynamic>>)
        .docs
        .map((doc) => StoreDeviceRecord.fromFirestore(doc.id, doc.data()))
        .toList(growable: false);
    var roles = (results[2] as QuerySnapshot<Map<String, dynamic>>)
        .docs
        .map((doc) => StoreRoleDefinition.fromMap(doc.data()))
        .toList(growable: false);

    if (roles.isEmpty) {
      roles = StoreAccessDefaults.all;
    }

    return StoreAccessSnapshot(users: users, devices: devices, roles: roles);
  }

  Future<String> ensureOwnerUser({
    required String storeId,
    required String ownerEmail,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('No hay una sesión de Firebase activa.');

    final ref = _users(storeId).doc(uid);
    await ref.set({
      'userId': uid,
      'authUid': uid,
      'storeId': storeId,
      'displayName': ownerEmail.split('@').first,
      'email': ownerEmail.trim().toLowerCase(),
      'roleId': 'owner',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'permissionOverrides': <String, bool>{},
    }, SetOptions(merge: true));

    await _seedRoles(storeId);
    await registerCurrentDevice(storeId: storeId, userId: uid);
    return uid;
  }

  Future<String> joinAsUser({
    required String storeId,
    required String displayName,
    required String invitationCode,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('No hay una sesión de Firebase activa.');

    final userId = uid;
    final ref = _users(storeId).doc(userId);
    final existing = await ref.get();
    final existingData = existing.data() ?? <String, dynamic>{};

    if (existing.exists) {
      // Once the user document exists, a member is only allowed to update
      // their own display name and activity timestamp. Do not try to rewrite
      // role/status/permissions from the join flow.
      await ref.update({
        'displayName': displayName.trim(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'userId': userId,
        'authUid': uid,
        'storeId': storeId,
        'displayName': displayName.trim(),
        'roleId': 'employee',
        'status': 'active',
        'inviteCode': invitationCode.trim().toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'permissionOverrides': <String, bool>{},
      });
    }

    await registerCurrentDevice(storeId: storeId, userId: userId);
    return userId;
  }

  Future<void> _seedRoles(String storeId) async {
    final batch = firestore.batch();
    for (final role in StoreAccessDefaults.all) {
      batch.set(_roles(storeId).doc(role.id), role.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> registerCurrentDevice({
    required String storeId,
    required String userId,
  }) async {
    final descriptor = await deviceRegistry.describeCurrentDevice();
    final ref = _devices(storeId).doc(descriptor.deviceId);

    // Do not read a missing device document before writing it. The security
    // rule intentionally allows creation from the joined user context, while
    // updates are restricted to the device heartbeat fields.
    await ref.set({
      'deviceId': descriptor.deviceId,
      'userId': userId,
      'storeId': storeId,
      'platform': descriptor.platform,
      'osVersion': descriptor.osVersion,
      'manufacturer': descriptor.manufacturer,
      'model': descriptor.model,
      'appVersion': descriptor.appVersion,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'active': true,
    }, SetOptions(merge: true));
    await _users(storeId).doc(userId).set(
      {'lastSeenAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> setOwnerEmail({
    required String storeId,
    required String ownerEmail,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('No hay una sesión de Firebase activa.');
    final normalized = ownerEmail.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw ArgumentError.value(ownerEmail, 'ownerEmail', 'correo no válido');
    }
    await _users(storeId).doc(uid).update({
      'email': normalized,
    });
  }

  Future<void> setUserRole({
    required String storeId,
    required String userId,
    required String roleId,
  }) async {
    if (roleId == 'owner') {
      throw StateError('El rol de propietario no se puede asignar desde esta pantalla.');
    }
    await _users(storeId).doc(userId).update({
      'roleId': roleId,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setUserStatus({
    required String storeId,
    required String userId,
    required String status,
  }) async {
    if (!{'active', 'suspended', 'revoked'}.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    await _users(storeId).doc(userId).update({'status': status});
  }

  Future<void> setPermissionOverride({
    required String storeId,
    required String userId,
    required String permission,
    required bool enabled,
  }) async {
    await _users(storeId).doc(userId).update({
      'permissionOverrides.$permission': enabled,
    });
  }

  Future<void> revokeDevice({
    required String storeId,
    required String deviceId,
    String reason = 'Acceso revocado por el administrador',
  }) async {
    await _devices(storeId).doc(deviceId).update({
      'active': false,
      'revokedReason': reason,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }
}
