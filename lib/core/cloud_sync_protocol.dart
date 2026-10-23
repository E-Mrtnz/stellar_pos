/// Pure domain contracts for incremental sync.
///
/// This file deliberately has no Firebase or Hive dependency. It describes
/// validated event envelopes and conflict decisions; it does not perform I/O.
enum CloudSyncOperation { create, update, delete }

enum CloudSyncEventStatus { pending, inFlight, delivered, blocked }

/// Durable event envelope persisted by the local Hive-backed outbox.
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
    this.nextAttemptAt,
    this.payload = const <String, Object?>{},
  })  : assert(eventId != ''),
        assert(storeId != ''),
        assert(entityType != ''),
        assert(entityId != '');

  final String eventId;
  final String storeId;
  final String entityType;
  final String entityId;
  final CloudSyncOperation operation;
  final int localVersion;
  final DateTime createdAt;
  final CloudSyncEventStatus status;
  final int attemptCount;
  /// Earliest UTC time this pending event may be retried after a transient failure.
  final DateTime? nextAttemptAt;
  /// Entity-specific data. The trusted server must still validate its schema.
  final Map<String, Object?> payload;

  CloudSyncEvent copyWith({
    CloudSyncEventStatus? status,
    int? attemptCount,
    DateTime? nextAttemptAt,
    Map<String, Object?>? payload,
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
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      payload: payload ?? this.payload,
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
  if (event.storeId.trim().isEmpty || activeStoreId.trim().isEmpty) {
    return 'missing-store-id';
  }
  if (event.storeId != activeStoreId) return 'store-mismatch';
  if (event.status != CloudSyncEventStatus.pending) return 'not-pending';
  if (event.eventId.trim().isEmpty) return 'missing-event-id';
  if (event.entityType.trim().isEmpty) return 'missing-entity-type';
  if (event.entityId.trim().isEmpty) return 'missing-entity-id';
  if (event.localVersion < 0) return 'invalid-local-version';
  if (event.attemptCount < 0) return 'invalid-attempt-count';
  if (!_isJsonValue(event.payload)) return 'invalid-payload';
  return null;
}

/// A remote change cursor is scoped to one store and must only move forward.
///
/// Durable local storage is implemented separately. A remote pull transport
/// must not advance the persisted cursor until a whole page is applied.
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


/// Conflict categories are explicit because business records cannot safely use
/// one generic last-write-wins strategy.
enum CloudSyncConflictKind {
  /// Immutable record with a stable ID; same ID + same content is idempotent.
  immutableDuplicate,
  /// Mutable descriptive data where an explicit version comparison is valid.
  versionedMetadata,
  /// Quantities must be represented as movements or transactionally merged.
  inventoryMovement,
  /// Sales are immutable facts and require server-side idempotency.
  sale,
  /// Money movements are immutable ledger entries.
  payment,
  /// Customer balances/debts require ledger-aware reconciliation.
  debt,
}

enum CloudSyncConflictAction {
  acceptDuplicate,
  applyIfNewer,
  appendMovement,
  rejectAndReconcile,
}

CloudSyncConflictAction conflictActionFor(CloudSyncConflictKind kind) {
  switch (kind) {
    case CloudSyncConflictKind.immutableDuplicate:
      return CloudSyncConflictAction.acceptDuplicate;
    case CloudSyncConflictKind.versionedMetadata:
      return CloudSyncConflictAction.applyIfNewer;
    case CloudSyncConflictKind.inventoryMovement:
      return CloudSyncConflictAction.appendMovement;
    case CloudSyncConflictKind.sale:
    case CloudSyncConflictKind.payment:
    case CloudSyncConflictKind.debt:
      return CloudSyncConflictAction.rejectAndReconcile;
  }
}


bool _isJsonValue(Object? value) {
  if (value == null || value is String || value is bool || value is int) {
    return true;
  }
  if (value is double) return value.isFinite;
  if (value is List) return value.every(_isJsonValue);
  if (value is Map) {
    return value.entries.every((entry) =>
        entry.key is String && _isJsonValue(entry.value));
  }
  return false;
}
