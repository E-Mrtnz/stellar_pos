import 'package:stellar_pos/core/data/datasources/data_source.dart';
import 'package:stellar_pos/core/data/datasources/in_memory_data_source.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Transitional repository used while the app has no persistent database.
///
/// The repository now depends on the data-source boundary, so replacing the
/// in-memory implementation with Hive/SQLite later does not require changing
/// the application-facing repository contract.
class InMemoryRepository<T extends SyncableEntity> implements Repository<T> {
  final LocalDataSource<T> _dataSource;

  InMemoryRepository({LocalDataSource<T>? dataSource})
      : _dataSource = dataSource ?? InMemoryDataSource<T>();

  @override
  Future<List<T>> getAll() => _dataSource.getAll();

  @override
  Future<T?> getById(String id) => _dataSource.getById(id);

  @override
  Future<void> save(T entity) => _dataSource.save(entity);

  @override
  Future<void> delete(String id) => _dataSource.delete(id);
}
