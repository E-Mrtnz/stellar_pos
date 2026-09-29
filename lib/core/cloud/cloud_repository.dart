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
  final CloudSyncEngine engine;

  CloudRepository({
    required this.local,
    required this.cloud,
    required this.scope,
    required this.collection,
    required this.fromMap,
    SyncQueue? queue,
    CloudSyncEngine? engine,
  })  : queue = queue ?? SyncQueue(),
        engine = engine ?? CloudSyncEngine();

  @override
  Future<List<T>> getAll() => local.getAll();

  @override
  Future<T?> getById(String id) => local.getById(id);

  @override
  Future<void> save(T entity) async {
    final prepared = _prepareLocalEntity(entity);
    await local.save(prepared);
    await queue.enqueueUpsert(
      collection: collection,
      entityId: prepared.id,
      payload: prepared.toMap(),
    );
  }

  @override
  Future<void> delete(String id) async {
    final existing = await local.getById(id);
    await local.delete(id);
    await queue.enqueueDelete(
      collection: collection,
      entityId: id,
      payload: existing?.metadata.toMap(),
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

  Future<CloudSyncResult> sync() => engine.sync<T>(
        collection: collection,
        scope: scope,
        local: local,
        cloud: cloud,
        fromMap: fromMap,
      );
}
