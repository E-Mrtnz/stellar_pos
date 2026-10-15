import 'package:stellar_pos/core/cloud_sync_protocol.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Durable local outbox for future sync events.
///
/// This class only stores queue metadata in Hive. It intentionally has no
/// transport and cannot send business records to Firebase. Callers must enqueue
/// only as part of a correctly coordinated local mutation workflow.
class CloudSyncOutbox {
  CloudSyncOutbox({this.boxName = 'cloud_sync_outbox'});

  final String boxName;

  Future<void> enqueue(CloudSyncEvent event) async {
    final box = await LocalStorage.openBox(boxName);
    final existing = box.get(event.eventId);
    if (existing != null) {
      final stored = _decode(existing);
      if (stored.storeId != event.storeId ||
          stored.entityType != event.entityType ||
          stored.entityId != event.entityId ||
          stored.operation != event.operation) {
        throw StateError(
          'El identificador de evento ya existe con otro contenido.',
        );
      }
      // Stable event ID makes enqueue idempotent; do not reset delivery state.
      return;
    }
    await box.put(event.eventId, _encode(event));
    await box.flush();
  }

  Future<List<CloudSyncEvent>> pendingForStore(String storeId) async {
    final box = await LocalStorage.openBox(boxName);
    final events = <CloudSyncEvent>[];
    for (final value in box.values) {
      final event = _decode(value);
      if (event.storeId == storeId &&
          event.status == CloudSyncEventStatus.pending) {
        events.add(event);
      }
    }
    events.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<CloudSyncEvent>.unmodifiable(events);
  }

  Future<void> markInFlight(String eventId) =>
      _updateStatus(eventId, CloudSyncEventStatus.inFlight);

  Future<void> markDelivered(String eventId) =>
      _updateStatus(eventId, CloudSyncEventStatus.delivered);

  Future<void> markBlocked(String eventId) =>
      _updateStatus(eventId, CloudSyncEventStatus.blocked);

  Future<void> retry(String eventId) async {
    final box = await LocalStorage.openBox(boxName);
    final value = box.get(eventId);
    if (value == null) throw StateError('No existe el evento solicitado.');
    final event = _decode(value);
    await box.put(
      eventId,
      _encode(event.copyWith(
        status: CloudSyncEventStatus.pending,
        attemptCount: event.attemptCount + 1,
      )),
    );
    await box.flush();
  }

  Future<void> _updateStatus(
    String eventId,
    CloudSyncEventStatus status,
  ) async {
    final box = await LocalStorage.openBox(boxName);
    final value = box.get(eventId);
    if (value == null) throw StateError('No existe el evento solicitado.');
    await box.put(eventId, _encode(_decode(value).copyWith(status: status)));
    await box.flush();
  }

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
  }
}
