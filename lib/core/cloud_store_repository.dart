import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stellar_pos/core/cloud_firebase.dart';

/// Metadata for a shared STELLAR POS store.
///
/// A store is a shared data space, not an online storefront. The visible name
/// is descriptive and is deliberately not used as the store identifier.
class CloudStore {
  const CloudStore({
    required this.id,
    required this.name,
    required this.ownerUid,
  });

  final String id;
  final String name;
  final String ownerUid;
}

/// Application-facing boundary for explicit store creation.
abstract interface class CloudStoreGateway {
  Future<CloudStore> createStore({required String name});

  /// Returns only active stores belonging to the currently authenticated user.
  Future<List<CloudStore>> listMyStores();
}

/// Explicit store-creation operations. This repository does not synchronize
/// products, sales, inventory, or any other local Hive records.
class CloudStoreRepository implements CloudStoreGateway {
  CloudStoreRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Random? random,
  })  : _firestoreOverride = firestore,
        _authOverride = auth,
        _random = random ?? Random.secure();

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  final Random _random;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

  /// Creates a store and its initial owner membership in one atomic batch.
  ///
  /// Firestore Security Rules must allow this exact paired write before this
  /// method can succeed. No product or business data is uploaded here.
  @override
  Future<CloudStore> createStore({required String name}) async {
    await CloudFirebase.ensureReady();

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión antes de crear una tienda.');
    }

    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'El nombre de la tienda es obligatorio.');
    }
    if (normalizedName.length > 80) {
      throw ArgumentError.value(name, 'name', 'El nombre no puede superar 80 caracteres.');
    }

    final storeId = _newStoreId();
    final storeRef = _firestore.collection('stores').doc(storeId);
    final memberRef = storeRef.collection('members').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.set(storeRef, <String, Object?>{
      'name': normalizedName,
      'ownerUid': user.uid,
      'schemaVersion': 1,
      'createdAt': now,
      'updatedAt': now,
    });
    batch.set(memberRef, <String, Object?>{
      'uid': user.uid,
      'role': 'owner',
      'status': 'active',
      'createdAt': now,
    });
    await batch.commit();

    return CloudStore(
      id: storeId,
      name: normalizedName,
      ownerUid: user.uid,
    );
  }

  /// Queries the user's active memberships, then reads each matching store.
  ///
  /// The query is constrained by the authenticated UID and active status; it
  /// does not scan products, sales, inventory, or any business collection.
  @override
  Future<List<CloudStore>> listMyStores() async {
    await CloudFirebase.ensureReady();

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión para consultar tus tiendas.');
    }

    final memberships = await _firestore
        .collectionGroup('members')
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .get();

    final stores = <CloudStore>[];
    for (final membership in memberships.docs) {
      final storeRef = membership.reference.parent.parent;
      if (storeRef == null) continue;
      final storeSnapshot = await storeRef.get();
      if (!storeSnapshot.exists) continue;
      final data = storeSnapshot.data();
      if (data == null || data['name'] is! String || data['ownerUid'] is! String) {
        continue;
      }
      stores.add(CloudStore(
        id: storeSnapshot.id,
        name: data['name'] as String,
        ownerUid: data['ownerUid'] as String,
      ));
    }

    stores.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List<CloudStore>.unmodifiable(stores);
  }

  String _newStoreId() => List<String>.generate(
        20,
        (_) => _alphabet[_random.nextInt(_alphabet.length)],
        growable: false,
      ).join();
}
