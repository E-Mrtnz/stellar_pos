/// Pure domain contracts for the future incremental sync worker.
///
/// This file deliberately has no Firebase or Hive dependency. It does not
/// enqueue, persist, upload, download, or apply business records by itself.
enum CloudSyncOperation { create, update, delete }

enum CloudSyncEventStatus { pending, inFlight, delivered, blocked }

/// Durable-event shape that a future Hive-backed outbox must persist.
///
/// [eventId] must remain stable across retries. [storeId] prevents an event
/// from being sent to a different store after the active account changes.
class CloudSyncEvent {
  const CloudSyncEvent({
    required this.eventId,
    required this.storeId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.localVersion,
    required this.createdAt,
    this.status = CloudSyncEventStatus.pending,
    this.attemptCount = 0,
  })  : assert(eventId != ''),
        assert(storeId != ''),
        assert(entityType != ''),
        assert(entityId != ''),
        assert(localVersion >= 0),
        assert(attemptCount >= 0);

  final String eventId;
  final String storeId;
  final String entityType;
  final String entityId;
  final CloudSyncOperation operation;
  final int localVersion;
  final DateTime createdAt;
  final CloudSyncEventStatus status;
  final int attemptCount;

  CloudSyncEvent copyWith({
    CloudSyncEventStatus? status,
    int? attemptCount,
  }) {
    return CloudSyncEvent(
      eventId: eventId,
      storeId: storeId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      localVersion: localVersion,
      createdAt: createdAt,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }
}

/// Validates an event before a future worker may send it.
///
/// Returns a stable reason code instead of throwing so callers can distinguish
/// permanent blocks from transient transport failures. This does not replace
/// server-side authorization or Firestore Security Rules.
String? validateCloudSyncEvent(
  CloudSyncEvent event, {
  required String activeStoreId,
}) {
  if (event.storeId != activeStoreId) return 'store-mismatch';
  if (event.status != CloudSyncEventStatus.pending) return 'not-pending';
  if (event.eventId.trim().isEmpty) return 'missing-event-id';
  if (event.entityType.trim().isEmpty) return 'missing-entity-type';
  if (event.entityId.trim().isEmpty) return 'missing-entity-id';
  if (event.localVersion < 0) return 'invalid-local-version';
  if (event.attemptCount < 0) return 'invalid-attempt-count';
  return null;
}

/// A remote change cursor is scoped to one store and must only move forward.
///
/// The actual remote transport and durable cursor storage are intentionally
/// not implemented here.
class CloudSyncCursor {
  const CloudSyncCursor({
    required this.storeId,
    required this.version,
  }) : assert(storeId != ''),
       assert(version >= 0);

  final String storeId;
  final int version;

  /// Returns the newer cursor, or null if the update belongs to another store
  /// or would move the cursor backwards.
  CloudSyncCursor? advanceTo(CloudSyncCursor candidate) {
    if (candidate.storeId != storeId || candidate.version < version) {
      return null;
    }
    return candidate;
  }
}
