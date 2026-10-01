import 'package:stellar_pos/core/cloud/cloud_data_source.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_scope.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_engine.dart';
import 'package:stellar_pos/core/cloud/sync_queue.dart';
import 'package:stellar_pos/core/data/datasources/data_source.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Repository that keeps Hive as the fast local source while recording every
/// local mutation for the cloud synchronization engine.
///
/// Providers depend only on [Repository]. Firestore remains hidden behind
/// [CloudDataSource].
class CloudRepository<T extends SyncableEntity> implements Repository<T> {
  final LocalDataSource<T> local;
  final CloudDataSource<T> cloud;
  final CloudSyncScope scope;
  final String collection;
  final T Function(Map<String, dynamic> map) fromMap;
  final SyncQueue queue;
  late final CloudSyncEngine engine;

  CloudRepository({
    required this.local,
    required this.cloud,
    required this.scope,
    required this.collection,
    required this.fromMap,
    SyncQueue? queue,
    CloudSyncEngine? engine,
  }) : queue = queue ?? SyncQueue() {
    // The constructor parameter has the same name as the field.
    // Explicitly assign the field so the repository always owns the engine.
    this.engine = engine ?? CloudSyncEngine(queue: this.queue);
  }

  @override
  Future<List<T>> getAll() => local.getAll();

  @override
  Future<T?> getById(String id) => local.getById(id);

  @override
  Future<void> save(T entity) async {
    // Local Hive remains the source of truth. The automatic synchronization
    // engine scans pending local records and sends them directly to Firestore.
    // Keeping upserts out of the durable queue prevents the queue from becoming
    // a second source of truth during large migrations.
    final prepared = _prepareLocalEntity(entity);
    await local.save(prepared);
  }

  @override
  Future<void> delete(String id) async {
    final existing = await local.getById(id);
    await local.delete(id);
    await queue.enqueueDelete(
      collection: collection,
      entityId: id,
      payload: existing?.metadata.toMap(),
      storeId: scope.storeId,
    );
  }

  T _prepareLocalEntity(T entity) {
    final metadata = entity.metadata;
    final needsNewVersion =
        metadata.syncState == SyncState.synced ||
        metadata.storeId != scope.storeId ||
        metadata.deviceId != scope.deviceId;

    final nextMetadata = needsNewVersion
        ? metadata.touch(syncState: SyncState.pending)
        : SyncMetadata(
            createdAt: metadata.createdAt,
            updatedAt: metadata.updatedAt,
            version: metadata.version,
            schemaVersion: metadata.schemaVersion,
            syncState: SyncState.pending,
            lastSyncedAt: metadata.lastSyncedAt,
            deletedAt: metadata.deletedAt,
            deviceId: scope.deviceId,
            storeId: scope.storeId,
          );

    return _copyWithMetadata(entity, scope.applyTo(nextMetadata));
  }

  T _copyWithMetadata(T entity, SyncMetadata metadata) {
    final map = Map<String, dynamic>.from(entity.toMap());
    map['metadata'] = metadata.toMap();
    return _fromMap(map);
  }

  T _fromMap(Map<String, dynamic> map) => fromMap(map);

  Future<bool> applyRemoteData(Map<String, dynamic> data) async {
    final remote = fromMap(Map<String, dynamic>.from(data));
    if (remote.metadata.storeId != null &&
        remote.metadata.storeId != scope.storeId) {
      return false;
    }

    final localEntity = await local.getById(remote.id);
    if (localEntity != null &&
        (localEntity.metadata.syncState == SyncState.pending ||
            localEntity.metadata.syncState == SyncState.updated)) {
      final localUpdated = localEntity.metadata.updatedAt;
      final remoteUpdated = remote.metadata.updatedAt;
      if (!remoteUpdated.isAfter(localUpdated)) {
        return false;
      }
    }

    final synced = _copyWithMetadata(
      remote,
      remote.metadata.markSynced(),
    );
    await local.save(synced);
    return true;
  }

  /// Applies a physical server-side removal without running a collection-wide sync.
  Future<bool> applyRemoteDelete(String id) async {
    final localEntity = await local.getById(id);
    if (localEntity == null) return false;

    if (localEntity.metadata.syncState == SyncState.pending ||
        localEntity.metadata.syncState == SyncState.updated) {
      return false;
    }

    await local.delete(id);
    return true;
  }

  Future<CloudSyncResult> sync() => engine.sync<T>(
        collection: collection,
        scope: scope,
        local: local,
        cloud: cloud,
        fromMap: fromMap,
      );

  /// Replaces the local collection with the cloud snapshot when a device
  /// joins an existing store. This is intentionally separate from normal
  /// local-first synchronization so pre-existing local data is never uploaded
  /// into a store merely because the device joined it.
  Future<CloudSyncResult> restoreFromCloud() => engine.restoreFromCloud<T>(
        collection: collection,
        local: local,
        cloud: cloud,
        fromMap: fromMap,
      );
}
