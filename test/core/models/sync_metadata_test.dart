import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/models/sync_metadata.dart';

void main() {
  test('touch increments version and marks the entity as updated', () {
    final created = DateTime.utc(2026, 1, 1, 10);
    final metadata = SyncMetadata(
      createdAt: created,
      updatedAt: created,
      version: 3,
      schemaVersion: 2,
      syncState: SyncState.synced,
    );

    final touched = metadata.touch(now: DateTime.utc(2026, 1, 1, 11));

    expect(touched.createdAt, created);
    expect(touched.updatedAt, DateTime.utc(2026, 1, 1, 11));
    expect(touched.version, 4);
    expect(touched.schemaVersion, 2);
    expect(touched.syncState, SyncState.updated);
  });

  test('round trips synchronization metadata through a map', () {
    final metadata = SyncMetadata(
      createdAt: DateTime.utc(2026, 2, 1, 8),
      updatedAt: DateTime.utc(2026, 2, 2, 9),
      version: 7,
      schemaVersion: 3,
      syncState: SyncState.synced,
      lastSyncedAt: DateTime.utc(2026, 2, 2, 10),
      deviceId: 'device-1',
      storeId: 'store-1',
    );

    final restored = SyncMetadata.fromMap(metadata.toMap());

    expect(restored.createdAt, metadata.createdAt);
    expect(restored.updatedAt, metadata.updatedAt);
    expect(restored.version, 7);
    expect(restored.schemaVersion, 3);
    expect(restored.syncState, SyncState.synced);
    expect(restored.lastSyncedAt, metadata.lastSyncedAt);
    expect(restored.deviceId, 'device-1');
    expect(restored.storeId, 'store-1');
  });

  test('markSynced preserves version and records sync time', () {
    final metadata = SyncMetadata(
      createdAt: DateTime.utc(2026, 3, 1),
      updatedAt: DateTime.utc(2026, 3, 2),
      version: 5,
      syncState: SyncState.updated,
    );

    final synced = metadata.markSynced(at: DateTime.utc(2026, 3, 3));

    expect(synced.version, 5);
    expect(synced.updatedAt, metadata.updatedAt);
    expect(synced.syncState, SyncState.synced);
    expect(synced.lastSyncedAt, DateTime.utc(2026, 3, 3));
  });
}
