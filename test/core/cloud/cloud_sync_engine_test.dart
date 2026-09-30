import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/cloud/cloud_data_source.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_engine.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_scope.dart';
import 'package:stellar_pos/core/cloud/sync_checkpoint_store.dart';
import 'package:stellar_pos/core/cloud/sync_queue.dart';
import 'package:stellar_pos/core/data/datasources/data_source.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

void main() {
  group('CloudSyncEngine', () {
    test('does not resurrect an offline delete during initial bootstrap', () async {
      final local = _MemoryLocalDataSource();
      final deleted = _entity(
        id: 'product-1',
        state: SyncState.deleted,
        version: 2,
      );
      final queue = _MemorySyncQueue([
        SyncQueueItem(
          id: 'delete-1',
          collection: 'products',
          entityId: deleted.id,
          operation: SyncOperationType.delete,
          payload: deleted.metadata.toMap(),
          queuedAt: DateTime.utc(2026, 1, 1),
          storeId: 'store-a',
        ),
      ]);
      final cloud = _MemoryCloudDataSource(
        remote: [_entity(id: deleted.id, version: 1)],
        failDeletes: true,
      );

      await CloudSyncEngine(
        queue: queue,
        checkpoints: _MemoryCheckpointStore(),
      ).sync<_TestEntity>(
        collection: 'products',
        scope: const CloudSyncScope(storeId: 'store-a', deviceId: 'device-a'),
        local: local,
        cloud: cloud,
        fromMap: _TestEntity.fromMap,
      );

      expect(await local.getById('product-1'), isNull);
      expect(queue.pendingItems, hasLength(1));
    });

    test('keeps a local pending mutation over an older remote copy', () async {
      final local = _MemoryLocalDataSource();
      final localEntity = _entity(
        id: 'product-1',
        state: SyncState.pending,
        version: 3,
        updatedAt: DateTime.utc(2026, 1, 3),
      );
      await local.save(localEntity);

      final cloud = _MemoryCloudDataSource(
        remote: [
          _entity(
            id: 'product-1',
            version: 2,
            updatedAt: DateTime.utc(2026, 1, 2),
          ),
        ],
      );

      await CloudSyncEngine(
        queue: _MemorySyncQueue(),
        checkpoints: _MemoryCheckpointStore(),
      ).sync<_TestEntity>(
        collection: 'products',
        scope: const CloudSyncScope(storeId: 'store-a', deviceId: 'device-a'),
        local: local,
        cloud: cloud,
        fromMap: _TestEntity.fromMap,
      );

      final result = await local.getById('product-1');
      expect(result?.metadata.version, 3);
      expect(result?.metadata.syncState, SyncState.pending);
    });

    test('applies a newer remote mutation over a synced local copy', () async {
      final local = _MemoryLocalDataSource();
      await local.save(_entity(
        id: 'product-1',
        state: SyncState.synced,
        version: 2,
        updatedAt: DateTime.utc(2026, 1, 2),
      ));

      final cloud = _MemoryCloudDataSource(
        remote: [
          _entity(
            id: 'product-1',
            version: 3,
            updatedAt: DateTime.utc(2026, 1, 3),
            deviceId: 'device-b',
          ),
        ],
      );

      final result = await CloudSyncEngine(
        queue: _MemorySyncQueue(),
        checkpoints: _MemoryCheckpointStore(),
      ).sync<_TestEntity>(
        collection: 'products',
        scope: const CloudSyncScope(storeId: 'store-a', deviceId: 'device-a'),
        local: local,
        cloud: cloud,
        fromMap: _TestEntity.fromMap,
      );

      expect(result.downloaded, greaterThanOrEqualTo(1));
      final synced = await local.getById('product-1');
      expect(synced?.metadata.version, 3);
      expect(synced?.metadata.syncState, SyncState.synced);
    });
  });
}

_TestEntity _entity({
  required String id,
  SyncState state = SyncState.synced,
  int version = 1,
  DateTime? updatedAt,
  String deviceId = 'device-a',
}) {
  final createdAt = DateTime.utc(2026, 1, 1);
  return _TestEntity(
    id: id,
    metadata: SyncMetadata(
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
      version: version,
      syncState: state,
      deviceId: deviceId,
      storeId: 'store-a',
    ),
  );
}

class _TestEntity implements SyncableEntity {
  @override
  final String id;

  @override
  final SyncMetadata metadata;

  const _TestEntity({
    required this.id,
    required this.metadata,
  });

  factory _TestEntity.fromMap(Map<String, dynamic> map) {
    return _TestEntity(
      id: map['id']?.toString() ?? '',
      metadata: SyncMetadata.fromMap(
        Map<String, dynamic>.from(map['metadata'] as Map),
      ),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'metadata': metadata.toMap(),
      };
}

class _MemoryLocalDataSource implements LocalDataSource<_TestEntity> {
  final Map<String, _TestEntity> _items = {};

  @override
  Future<List<_TestEntity>> getAll() async => _items.values.toList();

  @override
  Future<_TestEntity?> getById(String id) async => _items[id];

  @override
  Future<void> save(_TestEntity entity) async => _items[entity.id] = entity;

  @override
  Future<void> delete(String id) async => _items.remove(id);
}

class _MemoryCloudDataSource implements CloudDataSource<_TestEntity> {
  final List<_TestEntity> remote;
  final bool failDeletes;

  _MemoryCloudDataSource({
    required this.remote,
    this.failDeletes = false,
  });

  @override
  Future<List<_TestEntity>> getAll() async => List.of(remote);

  @override
  Future<List<_TestEntity>> getChangedSince(DateTime timestamp) async {
    return remote
        .where((entity) => entity.metadata.updatedAt.isAfter(timestamp))
        .toList();
  }

  @override
  Future<_TestEntity?> getById(String id) async {
    for (final entity in remote) {
      if (entity.id == id) return entity;
    }
    return null;
  }

  @override
  Future<void> save(_TestEntity entity) async {
    remote.removeWhere((item) => item.id == entity.id);
    remote.add(entity);
  }

  @override
  Future<void> delete(String id, {SyncMetadata? metadata}) async {
    if (failDeletes) {
      throw StateError('offline');
    }
    remote.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> markSynced(_TestEntity entity) async {}
}

class _MemorySyncQueue extends SyncQueue {
  final List<SyncQueueItem> pendingItems;

  _MemorySyncQueue([List<SyncQueueItem>? initial])
      : pendingItems = List<SyncQueueItem>.of(initial ?? const []);

  @override
  Future<void> enqueueUpsert({
    required String collection,
    required String entityId,
    required Map<String, dynamic> payload,
    String? storeId,
  }) async {
    pendingItems.removeWhere(
      (item) =>
          item.collection == collection &&
          item.entityId == entityId &&
          item.storeId == storeId,
    );
    pendingItems.add(SyncQueueItem(
      id: 'upsert-${pendingItems.length}',
      collection: collection,
      entityId: entityId,
      operation: SyncOperationType.upsert,
      payload: payload,
      queuedAt: DateTime.utc(2026, 1, 1),
      storeId: storeId,
    ));
  }

  @override
  Future<void> enqueueDelete({
    required String collection,
    required String entityId,
    Map<String, dynamic>? payload,
    String? storeId,
  }) async {
    pendingItems.removeWhere(
      (item) =>
          item.collection == collection &&
          item.entityId == entityId &&
          item.storeId == storeId,
    );
    pendingItems.add(SyncQueueItem(
      id: 'delete-${pendingItems.length}',
      collection: collection,
      entityId: entityId,
      operation: SyncOperationType.delete,
      payload: payload,
      queuedAt: DateTime.utc(2026, 1, 1),
      storeId: storeId,
    ));
  }

  @override
  Future<List<SyncQueueItem>> pending({
    String? collection,
    String? storeId,
  }) async {
    return pendingItems
        .where(
          (item) =>
              (collection == null || item.collection == collection) &&
              (storeId == null || item.storeId == storeId),
        )
        .toList();
  }

  @override
  Future<void> remove(String queueId) async {
    pendingItems.removeWhere((item) => item.id == queueId);
  }

  @override
  Future<void> markAttempt(String queueId, int attempts) async {
    final index = pendingItems.indexWhere((item) => item.id == queueId);
    if (index == -1) return;
    pendingItems[index] = pendingItems[index].copyWith(attempts: attempts);
  }
}

class _MemoryCheckpointStore extends SyncCheckpointStore {
  final Map<String, DateTime> _values = {};

  @override
  Future<DateTime?> get({
    required String storeId,
    required String collection,
  }) async =>
      _values['$storeId::$collection'];

  @override
  Future<void> save({
    required String storeId,
    required String collection,
    required DateTime timestamp,
  }) async {
    _values['$storeId::$collection'] = timestamp.toUtc();
  }

  @override
  Future<void> clear({
    required String storeId,
    required String collection,
  }) async {
    _values.remove('$storeId::$collection');
  }
}
