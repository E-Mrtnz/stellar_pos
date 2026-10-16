import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 14);

  CloudSyncEvent event({
    String eventId = 'evt-1',
    String storeId = 'store-a',
    CloudSyncEventStatus status = CloudSyncEventStatus.pending,
    int localVersion = 1,
  }) =>
      CloudSyncEvent(
        eventId: eventId,
        storeId: storeId,
        entityType: 'product',
        entityId: 'product-1',
        operation: CloudSyncOperation.update,
        localVersion: localVersion,
        createdAt: createdAt,
        status: status,
      );

  group('validateCloudSyncEvent', () {
    test('accepts a pending event for the active store', () {
      expect(
        validateCloudSyncEvent(event(), activeStoreId: 'store-a'),
        isNull,
      );
    });

    test('blocks events belonging to a different store', () {
      expect(
        validateCloudSyncEvent(event(storeId: 'store-b'), activeStoreId: 'store-a'),
        'store-mismatch',
      );
    });

    test('does not resend delivered or in-flight events as pending', () {
      expect(
        validateCloudSyncEvent(
          event(status: CloudSyncEventStatus.delivered),
          activeStoreId: 'store-a',
        ),
        'not-pending',
      );
      expect(
        validateCloudSyncEvent(
          event(status: CloudSyncEventStatus.inFlight),
          activeStoreId: 'store-a',
        ),
        'not-pending',
      );
    });

    test('validator rejects negative retry counters', () {
      final invalid = CloudSyncEvent(
        eventId: 'evt-negative-attempts',
        storeId: 'store-a',
        entityType: 'product',
        entityId: 'product-1',
        operation: CloudSyncOperation.update,
        localVersion: 1,
        createdAt: createdAt,
        attemptCount: -1,
      );

      expect(
        validateCloudSyncEvent(invalid, activeStoreId: 'store-a'),
        'invalid-attempt-count',
      );
    });

    test('validator rejects negative local versions', () {
      final invalid = CloudSyncEvent(
        eventId: 'evt-negative-version',
        storeId: 'store-a',
        entityType: 'product',
        entityId: 'product-1',
        operation: CloudSyncOperation.update,
        localVersion: -1,
        createdAt: createdAt,
      );

      expect(
        validateCloudSyncEvent(invalid, activeStoreId: 'store-a'),
        'invalid-local-version',
      );
    });

    test('rejects blank identifiers and entity types', () {
      expect(
        validateCloudSyncEvent(
          event(eventId: '   '),
          activeStoreId: 'store-a',
        ),
        'missing-event-id',
      );
      final invalidEntity = CloudSyncEvent(
        eventId: 'evt-blank-entity',
        storeId: 'store-a',
        entityType: '   ',
        entityId: 'product-1',
        operation: CloudSyncOperation.update,
        localVersion: 1,
        createdAt: createdAt,
      );
      expect(
        validateCloudSyncEvent(invalidEntity, activeStoreId: 'store-a'),
        'missing-entity-type',
      );
    });

    test('keeps event identity stable when status changes for retry', () {
      final original = event();
      final retry = original.copyWith(
        status: CloudSyncEventStatus.pending,
        attemptCount: 2,
      );

      expect(retry.eventId, original.eventId);
      expect(retry.storeId, original.storeId);
      expect(retry.entityId, original.entityId);
      expect(retry.attemptCount, 2);
    });
  });

  group('cloud sync conflict policy', () {
    test('does not use last-write-wins for money or inventory', () {
      expect(conflictActionFor(CloudSyncConflictKind.inventoryMovement),
          CloudSyncConflictAction.appendMovement);
      expect(conflictActionFor(CloudSyncConflictKind.sale),
          CloudSyncConflictAction.rejectAndReconcile);
      expect(conflictActionFor(CloudSyncConflictKind.payment),
          CloudSyncConflictAction.rejectAndReconcile);
      expect(conflictActionFor(CloudSyncConflictKind.debt),
          CloudSyncConflictAction.rejectAndReconcile);
    });

    test('permits version comparison only for descriptive metadata', () {
      expect(conflictActionFor(CloudSyncConflictKind.versionedMetadata),
          CloudSyncConflictAction.applyIfNewer);
      expect(conflictActionFor(CloudSyncConflictKind.immutableDuplicate),
          CloudSyncConflictAction.acceptDuplicate);
    });
  });

  group('CloudSyncCursor', () {
    test('advances within the same store', () {
      const current = CloudSyncCursor(storeId: 'store-a', version: 3);
      const next = CloudSyncCursor(storeId: 'store-a', version: 4);

      expect(current.advanceTo(next)?.version, 4);
    });

    test('rejects a cursor from another store', () {
      const current = CloudSyncCursor(storeId: 'store-a', version: 3);
      const other = CloudSyncCursor(storeId: 'store-b', version: 4);

      expect(current.advanceTo(other), isNull);
    });

    test('rejects moving the cursor backwards', () {
      const current = CloudSyncCursor(storeId: 'store-a', version: 3);
      const older = CloudSyncCursor(storeId: 'store-a', version: 2);

      expect(current.advanceTo(older), isNull);
    });

    test('allows idempotent re-application of the same cursor', () {
      const current = CloudSyncCursor(storeId: 'store-a', version: 3);
      const same = CloudSyncCursor(storeId: 'store-a', version: 3);

      expect(current.advanceTo(same)?.version, 3);
    });
  });
}
