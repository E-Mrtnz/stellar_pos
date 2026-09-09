import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Application-facing persistence contract.
/// Providers/use cases depend on this abstraction, never on a database SDK.
abstract interface class Repository<T extends SyncableEntity> {
  Future<List<T>> getAll();
  Future<T?> getById(String id);
  Future<void> save(T entity);
  Future<void> delete(String id);
}
