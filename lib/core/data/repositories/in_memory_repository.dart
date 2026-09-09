import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Transitional repository used while the app has no persistent database.
/// It keeps the repository contract testable and can later be replaced by a
/// local implementation without changing the presentation layer.
class InMemoryRepository<T extends SyncableEntity> implements Repository<T> {
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
