import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:stellar_pos/core/cloud/cloud_collection.dart';
import 'package:stellar_pos/core/cloud/cloud_identity_store.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_service.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_engine.dart';
import 'package:stellar_pos/core/cloud/cloud_store_access_service.dart';

/// Manages the business/store identity that sits above the application data.
///
/// The Firestore document id is the immutable store id. The visible store
/// name and the invitation code are values associated with that id and may be
/// changed later without moving the store's data.
class CloudStoreService {
  final CloudIdentityStore identityStore;
  final CloudSyncService syncService;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final CloudStoreAccessService accessService;

  CloudStoreService({
    CloudIdentityStore? identityStore,
    CloudSyncService? syncService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    CloudStoreAccessService? accessService,
  })  : identityStore = identityStore ?? CloudIdentityStore(),
        syncService = syncService ?? CloudSyncService(),
        firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance,
        accessService = accessService ?? CloudStoreAccessService();

  Future<String?> getStoreId() => identityStore.getStoreId();
  Future<String?> getStoreName() => identityStore.getStoreName();
  Future<String?> getInviteCode() => identityStore.getInviteCode();
  Future<String?> getOwnerEmail() => identityStore.getOwnerEmail();

  Future<bool> get isConfigured async =>
      (await identityStore.getStoreId())?.isNotEmpty == true;

  Future<User> _ensureAuthenticated() async {
    final user = auth.currentUser;
    if (user == null) {
      throw StateError(
        'Debes iniciar sesión con una cuenta de Stellar POS antes de usar la nube.',
      );
    }
    return user;
  }

  Future<void> _ensureCanSelectStore(String storeId) async {
    final current = await identityStore.getStoreId();
    if (current != null && current != storeId) {
      throw StateError(
        'Este dispositivo ya pertenece a otra tienda. '
        'No se puede cambiar de tienda sin limpiar o migrar primero '
        'los datos locales.',
      );
    }
  }

  /// Creates a brand-new store and generates its immutable store id.
  ///
  /// The id comes from a Firestore auto-generated document reference, while
  /// the invitation code is a short human-friendly value.
  Future<void> createStore(String storeName) async {
    final user = await _ensureAuthenticated();
    final normalizedEmail = user.email?.trim().toLowerCase() ?? '';
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw StateError(
        'La cuenta de Firebase no tiene un correo válido para crear la tienda.',
      );
    }
    final normalizedName = storeName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        storeName,
        'storeName',
        'El nombre de la tienda no puede estar vacío.',
      );
    }

    final current = await identityStore.getStoreId();
    if (current != null) {
      throw StateError(
        'Este dispositivo ya está vinculado a una tienda. '
        'No se puede crear otra sin limpiar o migrar los datos locales.',
      );
    }

    final storeRef = firestore.collection(CloudCollection.stores).doc();

    for (var attempt = 0; attempt < 5; attempt++) {
      final inviteCode = _newInviteCode();
      final inviteRef =
          firestore.collection(CloudCollection.storeInvites).doc(inviteCode);
      final memberRef = storeRef.collection(CloudCollection.members).doc(user.uid);

      try {
        await firestore.runTransaction((transaction) async {
          final existingInvite = await transaction.get(inviteRef);
          if (existingInvite.exists) {
            throw _InviteCodeCollision();
          }

          final storeData = <String, dynamic>{
            'name': normalizedName,
            'ownerUid': user.uid,
            'inviteCode': inviteCode,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          transaction.set(storeRef, storeData);
          transaction.set(memberRef, <String, dynamic>{
            'storeId': storeRef.id,
            'uid': user.uid,
            'role': 'owner',
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.set(inviteRef, <String, dynamic>{
            'storeId': storeRef.id,
            'createdBy': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        await identityStore.setStoreIdentity(
          storeId: storeRef.id,
          storeName: normalizedName,
          ownerEmail: normalizedEmail,
          inviteCode: inviteCode,
        );
        await accessService.ensureOwnerUser(
          storeId: storeRef.id,
          ownerEmail: normalizedEmail,
        );
        await syncService.syncAll();
        return;
      } on _InviteCodeCollision {
        continue;
      }
    }

    throw StateError(
      'No se pudo generar un código de invitación disponible. '
      'Inténtalo nuevamente.',
    );
  }

  /// Joins an existing store using its invitation code.
  ///
  /// The code is the lookup key; the immutable store id returned by the
  /// invitation document is what becomes the local cloud identity.
  Future<void> joinStore(String displayName, String invitationCode) async {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'El nombre del usuario no puede estar vacío.');
    }
    final normalizedCode = invitationCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw ArgumentError.value(
        invitationCode,
        'invitationCode',
        'El código de invitación no puede estar vacío.',
      );
    }

    final user = await _ensureAuthenticated();
    final inviteRef =
        firestore.collection(CloudCollection.storeInvites).doc(normalizedCode);
    final inviteSnapshot = await _runJoinStep(
      'consultar la invitación',
      inviteRef.get,
    );

    if (!inviteSnapshot.exists) {
      throw StateError('El código de invitación no es válido.');
    }

    final invite = inviteSnapshot.data() ?? const <String, dynamic>{};
    final storeId = invite['storeId']?.toString().trim();
    if (storeId == null || storeId.isEmpty) {
      throw StateError('La invitación no contiene una tienda válida.');
    }

    await _ensureCanSelectStore(storeId);

    final storeRef =
        firestore.collection(CloudCollection.stores).doc(storeId);
    final memberRef =
        storeRef.collection(CloudCollection.members).doc(user.uid);
    final existingMember = await _runJoinStep(
      'comprobar la membresía',
      memberRef.get,
    );

    if (!existingMember.exists) {
      await _runJoinStep(
        'registrar la membresía de la tienda',
        () => memberRef.set(<String, dynamic>{
          'storeId': storeId,
          'uid': user.uid,
          'role': 'member',
          'inviteCode': normalizedCode,
          'createdAt': FieldValue.serverTimestamp(),
        }),
      );
    }

    // Verify the membership before continuing. This keeps a failed join from
    // being reported as successful and makes rule/configuration errors
    // visible at the exact step that failed.
    final verifiedMember = await _runJoinStep(
      'verificar la membresía creada',
      memberRef.get,
    );
    if (!verifiedMember.exists) {
      throw StateError(
        'Firebase no confirmó la membresía de este usuario en la tienda.',
      );
    }

    // Membership now exists, so the authenticated user can safely read the
    // store metadata protected by the Firestore rules.
    final storeSnapshot = await _runJoinStep(
      'consultar los datos de la tienda',
      storeRef.get,
    );
    if (!storeSnapshot.exists) {
      throw StateError('La tienda asociada a esta invitación no existe.');
    }

    final storeData = storeSnapshot.data() ?? const <String, dynamic>{};
    final storeName = storeData['name']?.toString().trim();
    if (storeName == null || storeName.isEmpty) {
      throw StateError('La tienda no tiene un nombre válido.');
    }

    await _runJoinStep(
      'crear el usuario de la tienda',
      () => accessService.joinAsUser(
        storeId: storeId,
        displayName: normalizedName,
        invitationCode: normalizedCode,
      ),
    );

    await identityStore.setStoreIdentity(
      storeId: storeId,
      storeName: storeName,
      inviteCode: normalizedCode,
    );
    // Onboarding is intentionally remote-authoritative: the device must
    // download the store's existing data instead of uploading whatever local
    // records happened to exist before joining it.
    await syncService.restoreFromCloud();
  }

  Future<void> updateOwnerEmail(String ownerEmail) async {
    final storeId = await identityStore.getStoreId();
    if (storeId == null) {
      throw StateError('No hay una tienda configurada en este dispositivo.');
    }
    await accessService.setOwnerEmail(storeId: storeId, ownerEmail: ownerEmail);
    await identityStore.setOwnerEmail(ownerEmail);
  }

  Future<void> renameStore(String storeName) async {
    final normalizedName = storeName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        storeName,
        'storeName',
        'El nombre de la tienda no puede estar vacío.',
      );
    }

    final storeId = await identityStore.getStoreId();
    if (storeId == null) {
      throw StateError('No hay una tienda configurada en este dispositivo.');
    }

    final user = await _ensureAuthenticated();
    final storeRef =
        firestore.collection(CloudCollection.stores).doc(storeId);
    final snapshot = await storeRef.get();
    if (!snapshot.exists) {
      throw StateError('La tienda configurada ya no existe en la nube.');
    }

    if (snapshot.data()?['ownerUid']?.toString() != user.uid) {
      throw StateError(
        'Solo el propietario de la tienda puede cambiar su nombre.',
      );
    }

    await storeRef.update(<String, dynamic>{
      'name': normalizedName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await identityStore.setStoreName(normalizedName);
  }

  /// Generates a new invitation code while keeping the same store id.
  Future<void> rotateInviteCode() async {
    final storeId = await identityStore.getStoreId();
    if (storeId == null) {
      throw StateError('No hay una tienda configurada en este dispositivo.');
    }

    final user = await _ensureAuthenticated();
    final storeRef =
        firestore.collection(CloudCollection.stores).doc(storeId);
    final storeSnapshot = await storeRef.get();
    if (!storeSnapshot.exists ||
        storeSnapshot.data()?['ownerUid']?.toString() != user.uid) {
      throw StateError(
        'Solo el propietario puede cambiar el código de invitación.',
      );
    }

    final oldCode = await identityStore.getInviteCode();

    for (var attempt = 0; attempt < 8; attempt++) {
      final newCode = _newInviteCode();
      if (newCode == oldCode) continue;

      final newInviteRef =
          firestore.collection(CloudCollection.storeInvites).doc(newCode);
      final oldInviteRef = oldCode == null
          ? null
          : firestore.collection(CloudCollection.storeInvites).doc(oldCode);

      try {
        await firestore.runTransaction((transaction) async {
          final existingNewInvite = await transaction.get(newInviteRef);
          if (existingNewInvite.exists) {
            throw _InviteCodeCollision();
          }

          transaction.set(newInviteRef, <String, dynamic>{
            'storeId': storeId,
            'createdBy': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });

          transaction.update(storeRef, <String, dynamic>{
            'inviteCode': newCode,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (oldInviteRef != null) {
            transaction.delete(oldInviteRef);
          }
        });

        await identityStore.setInviteCode(newCode);
        return;
      } on _InviteCodeCollision {
        continue;
      }
    }

    throw StateError(
      'No se pudo generar un nuevo código de invitación. '
      'Inténtalo nuevamente.',
    );
  }

  Future<T> _runJoinStep<T>(
    String step,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw StateError(
          'Firestore rechazó el paso "$step" por sus reglas de seguridad. '
          'Publica las reglas actuales del proyecto stellar-pos-8384.',
        );
      }
      rethrow;
    }
  }

  Future<CloudSyncResult> sync() => syncService.syncAll();

  /// Legacy bridge kept only so older callers do not silently break.
  ///
  /// New UI flows must use [createStore] or [joinStore] so the immutable
  /// store id cannot be confused with the visible store name.
  @Deprecated('Use createStore() or joinStore().')
  Future<void> configureStore(String storeId) async {
    final normalized = storeId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(storeId, 'storeId', 'cannot be empty');
    }

    final current = await identityStore.getStoreId();
    if (current != null && current != normalized) {
      throw StateError(
        'Cannot switch the cloud store on this device while local data '
        'belongs to another store. Clear or migrate the local data first.',
      );
    }

    await identityStore.setStoreIdentity(
      storeId: normalized,
      storeName: await identityStore.getStoreName() ?? normalized,
    );
    await syncService.syncAll();
  }

  static String _newInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final chars = List.generate(
      8,
      (_) => alphabet[random.nextInt(alphabet.length)],
    );
    return '${chars.sublist(0, 4).join()}-${chars.sublist(4).join()}';
  }
}

class _InviteCodeCollision implements Exception {}
