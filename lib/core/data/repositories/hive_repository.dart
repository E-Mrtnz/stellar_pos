import 'package:stellar_pos/core/data/datasources/data_source.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Repository implementation backed by a local data source.
///
/// Keeping the repository dependent on [DataSource] means the feature layer
/// does not need to know whether data comes from Hive, memory, or a future
/// remote/local synchronization source.
class HiveRepository<T extends SyncableEntity> implements Repository<T> {
  const HiveRepository(this.dataSource);

  final LocalDataSource<T> dataSource;

  @override
  Future<List<T>> getAll() => dataSource.getAll();

  @override
  Future<T?> getById(String id) => dataSource.getById(id);

  @override
  Future<void> save(T entity) => dataSource.save(entity);

  @override
  Future<void> delete(String id) => dataSource.delete(id);
}
