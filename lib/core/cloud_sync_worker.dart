import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stellar_pos/core/cloud_sync_outbox.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';
import 'package:stellar_pos/core/cloud_sync_retry_policy.dart';

enum CloudSyncDeliveryStatus { applied, duplicate }

class CloudSyncTransportException implements Exception {
  const CloudSyncTransportException(this.message, {required this.retryable});
  final String message;
  final bool retryable;
  @override
  String toString() => message;
}

abstract interface class CloudSyncTransport {
  Future<CloudSyncDeliveryStatus> send(CloudSyncEvent event);
}

class CloudFunctionsSyntheticSyncTransport implements CloudSyncTransport {
  CloudFunctionsSyntheticSyncTransport({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;
  final FirebaseFunctions _functions;

  @override
  Future<CloudSyncDeliveryStatus> send(CloudSyncEvent event) async {
    if (event.entityType != 'syntheticTestValue' ||
        event.operation != CloudSyncOperation.update ||
        event.payload.length != 1 ||
        event.payload['value'] is! String) {
      throw const CloudSyncTransportException(
        'El transporte remoto solo admite eventos sintéticos.',
        retryable: false,
      );
    }
    try {
      final response = await _functions
          .httpsCallable('acceptSyntheticSyncEvent')
          .call(<String, Object?>{
        'schemaVersion': 1,
        'storeId': event.storeId,
        'eventId': event.eventId,
        'entityType': event.entityType,
        'entityId': event.entityId,
        'operation': 'set',
        'localVersion': event.localVersion,
        'payload': event.payload,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['status'] == 'applied') return CloudSyncDeliveryStatus.applied;
      if (data['status'] == 'duplicate') return CloudSyncDeliveryStatus.duplicate;
      throw const CloudSyncTransportException(
        'El servidor devolvió un resultado de sincronización desconocido.',
        retryable: false,
      );
    } on FirebaseFunctionsException catch (error) {
      final retryable = const <String>{
        'unavailable', 'deadline-exceeded', 'resource-exhausted', 'internal',
      }.contains(error.code);
      throw CloudSyncTransportException(
        error.message ?? 'Falló el transporte de sincronización.',
        retryable: retryable,
      );
    }
  }
}

class CloudSyncRunSummary {
  const CloudSyncRunSummary({
    this.applied = 0,
    this.duplicates = 0,
    this.retried = 0,
    this.blocked = 0,
    this.paused = false,
  });
  final int applied;
  final int duplicates;
  final int retried;
  final int blocked;
  final bool paused;
}

abstract interface class CloudSyncSessionGate {
  Future<bool> canSyncStore(String storeId);
}

class FirebaseCloudSyncSessionGate implements CloudSyncSessionGate {
  FirebaseCloudSyncSessionGate({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<bool> canSyncStore(String storeId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final membership = await _firestore
        .doc('stores/$storeId/members/${user.uid}')
        .get();
    return membership.exists &&
        membership.data()?['uid'] == user.uid &&
        membership.data()?['status'] == 'active';
  }
}

/// Manually invoked, bounded worker for synthetic test events only.
/// Not wired to app startup, lifecycle timers, or commercial repositories.
class CloudSyncWorker {
  CloudSyncWorker({
    required CloudSyncOutbox outbox,
    required CloudSyncTransport transport,
    CloudSyncRetryPolicy retryPolicy = const CloudSyncRetryPolicy(),
    CloudSyncSessionGate sessionGate = const _AlwaysDeniedSessionGate(),
  })  : _outbox = outbox,
        _transport = transport,
        _retryPolicy = retryPolicy,
        _sessionGate = sessionGate;

  final CloudSyncOutbox _outbox;
  final CloudSyncTransport _transport;
  final CloudSyncRetryPolicy _retryPolicy;
  final CloudSyncSessionGate _sessionGate;

  Future<CloudSyncRunSummary> runOnce({
    required String storeId,
    int limit = 20,
  }) async {
    if (storeId.trim().isEmpty || storeId.contains('/')) {
      throw ArgumentError.value(storeId, 'storeId', 'Identificador de tienda inválido.');
    }
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'El límite debe estar entre 1 y 100.');
    }
    if (!await _sessionGate.canSyncStore(storeId)) {
      return const CloudSyncRunSummary(paused: true);
    }

    final pending = await _outbox.pendingForStore(storeId);
    var applied = 0;
    var duplicates = 0;
    var retried = 0;
    var blocked = 0;
    for (final event in pending.take(limit)) {
      // Commercial entities stay blocked until their own server contract exists.
      if (event.entityType != 'syntheticTestValue') {
        await _outbox.markBlocked(event.eventId);
        blocked++;
        continue;
      }
      final invalid = validateCloudSyncEvent(event, activeStoreId: storeId);
      if (invalid != null || event.payload.length != 1 ||
          event.payload['value'] is! String) {
        await _outbox.markBlocked(event.eventId);
        blocked++;
        continue;
      }
      await _outbox.markInFlight(event.eventId);
      try {
        final result = await _transport.send(event);
        await _outbox.markDelivered(event.eventId);
        if (result == CloudSyncDeliveryStatus.applied) {
          applied++;
        } else {
          duplicates++;
        }
      } on CloudSyncTransportException catch (error) {
        if (error.retryable && _retryPolicy.canRetry(event.attemptCount + 1)) {
          await _outbox.retry(event.eventId);
          retried++;
        } else {
          await _outbox.markBlocked(event.eventId);
          blocked++;
        }
      } on Object {
        await _outbox.markBlocked(event.eventId);
        blocked++;
      }
    }
    return CloudSyncRunSummary(
      applied: applied,
      duplicates: duplicates,
      retried: retried,
      blocked: blocked,
    );
  }
}

class _AlwaysDeniedSessionGate implements CloudSyncSessionGate {
  const _AlwaysDeniedSessionGate();
  @override
  Future<bool> canSyncStore(String storeId) async => false;
}
