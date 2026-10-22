import 'dart:convert';
import 'dart:async';

import 'package:stellar_pos/core/cloud_sync_protocol.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Minimal storage contract so outbox behavior can be tested without platform Hive.
abstract interface class CloudSyncOutboxStorage {
  Object? get(String key);
  Iterable<Object?> get values;
  Future<void> put(String key, Object value);
  Future<void> flush();
}

class _HiveCloudSyncOutboxStorage implements CloudSyncOutboxStorage {
  _HiveCloudSyncOutboxStorage(this.boxName);

  final String boxName;
  Future<dynamic> get _box => LocalStorage.openBox(boxName);
  Map<String, Object?> _cachedValues = <String, Object?>{};

  @override
  Object? get(String key) => _cachedValues[key];

  @override
  Iterable<Object?> get values => _cachedValues.values;

  Future<void> _refresh() async {
    final box = await _box;
    _cachedValues = <String, Object?>{
      for (final key in box.keys) key as String: box.get(key) as Object?,
    };
  }

  @override
  Future<void> put(String key, Object value) async {
    final box = await _box;
    await box.put(key, value);
    await _refresh();
  }

  @override
  Future<void> flush() async {
    final box = await _box;
    await box.flush();
  }
}

/// Durable local outbox for incremental-sync events.
///
/// This class stores event envelopes in Hive but does not coordinate writes
/// with commercial repositories. The worker currently transports only synthetic
/// test events; business events must remain disconnected until that is solved.
class CloudSyncOutbox {
  CloudSyncOutbox({
    this.boxName = 'cloud_sync_outbox',
    CloudSyncOutboxStorage? storage,
  }) : _storage = storage ?? _HiveCloudSyncOutboxStorage(boxName);

  final CloudSyncOutboxStorage _storage;
  final String boxName;
  Future<void> _operationTail = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> enqueue(CloudSyncEvent event) => _serialize(() async {
    if (_storage is _HiveCloudSyncOutboxStorage) await _storage._refresh();
    final existing = _storage.get(event.eventId);
    if (existing != null) {
      final stored = _decode(existing);
      if (stored.storeId != event.storeId ||
          stored.entityType != event.entityType ||
          stored.entityId != event.entityId ||
          stored.operation != event.operation ||
          stored.localVersion != event.localVersion ||
          !_samePayload(stored.payload, event.payload) ||
          !stored.createdAt.isAtSameMomentAs(event.createdAt)) {
        throw StateError(
          'El identificador de evento ya existe con otro contenido.',
        );
      }
      return;
    }
    final validationError = validateCloudSyncEvent(
      event,
      activeStoreId: event.storeId,
    );
    if (validationError != null) {
      throw StateError('El evento de sincronización no es válido: $validationError');
    }
    await _storage.put(event.eventId, _encode(event));
    await _storage.flush();
  });

  Future<List<CloudSyncEvent>> pendingForStore(String storeId) =>
      _serialize(() async {
    if (_storage is _HiveCloudSyncOutboxStorage) await _storage._refresh();
    final events = <CloudSyncEvent>[];
    for (final value in _storage.values) {
      final event = _decode(value);
      if (event.storeId == storeId &&
          event.status == CloudSyncEventStatus.pending) {
        events.add(event);
      }
    }
    events.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<CloudSyncEvent>.unmodifiable(events);
  });

  /// Atomically claims a pending event for one store so concurrent workers
  /// cannot deliver the same outbox record at the same time.
  Future<bool> claimForDelivery({
    required String eventId,
    required String storeId,
    required DateTime now,
  }) => _serialize(() async {
    if (_storage is _HiveCloudSyncOutboxStorage) await _storage._refresh();
    final raw = _storage.get(eventId);
    if (raw == null) return false;
    final event = _decode(raw);
    if (event.storeId != storeId ||
        event.status != CloudSyncEventStatus.pending ||
        (event.nextAttemptAt != null && event.nextAttemptAt!.isAfter(now))) {
      return false;
    }
    await _storage.put(
      eventId,
      _encode(event.copyWith(status: CloudSyncEventStatus.inFlight)),
    );
    await _storage.flush();
    return true;
  });

  Future<void> markInFlight(String eventId) =>
      _updateStatus(eventId, CloudSyncEventStatus.inFlight);
  Future<void> markDelivered(String eventId) =>
      _updateStatus(eventId, CloudSyncEventStatus.delivered);
  Future<void> markBlocked(String eventId) =>
      _updateStatus(eventId, CloudSyncEventStatus.blocked);

  /// Recovers events left in-flight when the app stopped unexpectedly.
  /// A remote transport must be idempotent before this is used for business data.
  Future<int> recoverInterruptedEvents({String? storeId}) => _serialize(() async {
    if (_storage is _HiveCloudSyncOutboxStorage) await _storage._refresh();
    var recovered = 0;
    final interrupted = <CloudSyncEvent>[];
    for (final value in _storage.values) {
      final event = _decode(value);
      if (event.status == CloudSyncEventStatus.inFlight &&
          (storeId == null || event.storeId == storeId)) {
        interrupted.add(event);
      }
    }
    for (final event in interrupted) {
      await _storage.put(
        event.eventId,
        _encode(event.copyWith(
          status: CloudSyncEventStatus.pending,
          attemptCount: event.attemptCount + 1,
        )),
      );
      recovered++;
    }
    if (recovered > 0) await _storage.flush();
    return recovered;
  });

  Future<void> retry(String eventId, {Duration delay = Duration.zero}) => _serialize(() async {
    if (_storage is _HiveCloudSyncOutboxStorage) await _storage._refresh();
    final value = _storage.get(eventId);
    if (value == null) throw StateError('No existe el evento solicitado.');
    final event = _decode(value);
    await _storage.put(
      eventId,
      _encode(event.copyWith(
        status: CloudSyncEventStatus.pending,
        attemptCount: event.attemptCount + 1,
        nextAttemptAt: DateTime.now().toUtc().add(delay),
      )),
    );
    await _storage.flush();
  });

  Future<void> _updateStatus(String eventId, CloudSyncEventStatus status) =>
      _serialize(() async {
    if (_storage is _HiveCloudSyncOutboxStorage) await _storage._refresh();
    final value = _storage.get(eventId);
    if (value == null) throw StateError('No existe el evento solicitado.');
    await _storage.put(eventId, _encode(_decode(value).copyWith(status: status)));
    await _storage.flush();
  });

  Map<String, Object?> _encode(CloudSyncEvent event) => <String, Object?>{
        'eventId': event.eventId,
        'storeId': event.storeId,
        'entityType': event.entityType,
        'entityId': event.entityId,
        'operation': event.operation.name,
        'localVersion': event.localVersion,
        'createdAt': event.createdAt.toUtc().toIso8601String(),
        'status': event.status.name,
        'attemptCount': event.attemptCount,
        'nextAttemptAt': event.nextAttemptAt?.toUtc().toIso8601String(),
        'payload': event.payload,
      };

  CloudSyncEvent _decode(Object? raw) {
    if (raw is! Map) {
      throw StateError('El evento guardado en la cola no es válido.');
    }
    try {
      final map = Map<String, Object?>.from(raw);
      return CloudSyncEvent(
        eventId: map['eventId'] as String,
        storeId: map['storeId'] as String,
        entityType: map['entityType'] as String,
        entityId: map['entityId'] as String,
        operation: CloudSyncOperation.values.byName(map['operation'] as String),
        localVersion: map['localVersion'] as int,
        createdAt: DateTime.parse(map['createdAt'] as String).toUtc(),
        status: CloudSyncEventStatus.values.byName(map['status'] as String),
        attemptCount: map['attemptCount'] as int,
        nextAttemptAt: map['nextAttemptAt'] is String
            ? DateTime.parse(map['nextAttemptAt'] as String).toUtc()
            : null,
        payload: map['payload'] is Map
            ? Map<String, Object?>.from(map['payload'] as Map)
            : const <String, Object?>{},
      );
    } on StateError {
      rethrow;
    } on Object catch (error) {
      throw StateError('El evento guardado en la cola está corrupto: $error');
    }
  }
}


bool _samePayload(Map<String, Object?> left, Map<String, Object?> right) =>
    jsonEncode(_canonicalizeJson(left)) == jsonEncode(_canonicalizeJson(right));

Object? _canonicalizeJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalizeJson(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalizeJson).toList(growable: false);
  }
  return value;
}
