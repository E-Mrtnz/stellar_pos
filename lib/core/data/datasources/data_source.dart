import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Storage boundary used by the data layer.
/// Implementations can be local (Hive/SQLite) or remote (cloud API/database).
abstract interface class DataSource<T extends SyncableEntity> {
  Future<List<T>> getAll();
  Future<T?> getById(String id);
  Future<void> save(T entity);
  Future<void> delete(String id);
}

abstract interface class LocalDataSource<T extends SyncableEntity>
    implements DataSource<T> {}

/// Optional optimized local persistence contract for migrations and bulk
/// synchronization preparation. Implementations can persist many entities in
/// one storage operation while callers remain compatible with simple local
/// data sources.
abstract interface class BatchLocalDataSource<T extends SyncableEntity> {
  Future<void> saveAll(Iterable<T> entities);
}

abstract interface class RemoteDataSource<T extends SyncableEntity>
    implements DataSource<T> {}
