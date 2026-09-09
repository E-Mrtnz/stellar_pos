import 'package:stellar_pos/core/data/datasources/data_source.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

/// In-memory local data source used until a persistent storage adapter is
/// introduced. It deliberately implements the same boundary expected from a
/// future Hive/SQLite data source.
class InMemoryDataSource<T extends SyncableEntity>
    implements LocalDataSource<T> {
  final Map<String, T> _items = <String, T>{};

  @override
  Future<List<T>> getAll() async => List.unmodifiable(_items.values);

  @override
  Future<T?> getById(String id) async => _items[id];

  @override
  Future<void> save(T entity) async {
    _items[entity.id] = entity;
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }
}
