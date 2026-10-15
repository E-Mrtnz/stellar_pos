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

  @override
  Object? get(String key) => _cachedValues[key];

  @override
  Iterable<Object?> get values => _cachedValues.values;

  Map<String, Object?> _cachedValues = <String, Object?>{};

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

/// Durable local outbox for future sync events.
///
/// This class only stores queue metadata in Hive. It intentionally has no
/// transport and cannot send business records to Firebase. Callers must enqueue
/// only as part of a correctly coordinated local mutation workflow.
class CloudSyncOutbox {
  CloudSyncOutbox({
    this.boxName = 'cloud_sync_outbox',
    CloudSyncOutboxStorage? storage,
  }) : _storage = storage ?? _HiveCloudSyncOutboxStorage(boxName);

  final CloudSyncOutboxStorage _storage;

  final String boxName;

  // Hive operations must be serialized: two simultaneous enqueue calls could
  // otherwise both observe a missing ID and overwrite each other's payload.
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
          !stored.createdAt.isAtSameMomentAs(event.createdAt)) {
        throw StateError(
          'El identificador de evento ya existe con otro contenido.',
        );
      }
      // Stable event ID makes enqueue idempotent; do not reset delivery state.
      return;
    }
    await _storage.put(event.eventId, _encode(event));
    await _storage.flush();
  });

  Future<List<CloudSyncEvent>> pendingForStore(String storeId) =>
      _serialize(() async {
    await (_storage is _HiveCloudSyncOutboxStorage ? _storage._refresh() : Future<void>.value());
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

  Future<void> markInFlight(String eventId) =>
      _updateStatus(eventId, CloudSyncEventStatus.inFlight);

  Future<void> markDelivered(String eventId) =>
      _updateStatus(eventId, CloudSyncEventStatus.delivered);

  Future<void> markBlocked(String eventId) =>
      _updateStatus(eventId, CloudSyncEventStatus.blocked);

  /// Recovers events left in-flight when the app stopped unexpectedly.
  ///
  /// The stable event ID must be used by an idempotent remote transport before
  /// this recovery is enabled for business data; a prior request may have
  /// reached the server even if the client never recorded its acknowledgement.
  Future<int> recoverInterruptedEvents() => _serialize(() async {
    if (_storage is _HiveCloudSyncOutboxStorage) await _storage._refresh();
    var recovered = 0;
    final interrupted = <CloudSyncEvent>[];
    for (final value in _storage.values) {
      final event = _decode(value);
      if (event.status == CloudSyncEventStatus.inFlight) {
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

  Future<void> retry(String eventId) => _serialize(() async {
    if (_storage is _HiveCloudSyncOutboxStorage) await _storage._refresh();
    final value = _storage.get(eventId);
    if (value == null) throw StateError('No existe el evento solicitado.');
    final event = _decode(value);
    await _storage.put(
      eventId,
      _encode(event.copyWith(
        status: CloudSyncEventStatus.pending,
        attemptCount: event.attemptCount + 1,
      )),
    );
    await _storage.flush();
  });

  Future<void> _updateStatus(
    String eventId,
    CloudSyncEventStatus status,
  ) => _serialize(() async {
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
      );
    } on StateError {
      rethrow;
    } on Object catch (error) {
      throw StateError('El evento guardado en la cola está corrupto: $error');
    }
  }
