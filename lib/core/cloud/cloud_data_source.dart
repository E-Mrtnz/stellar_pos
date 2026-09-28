import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Cloud persistence contract.
///
/// The UI and providers must never depend directly on a cloud SDK.
/// Implementations are responsible for translating cloud documents to and
/// from [SyncableEntity] instances.
abstract interface class CloudDataSource<T extends SyncableEntity> {
  Future<List<T>> getAll();

  Future<List<T>> getChangedSince(DateTime timestamp);

  Future<T?> getById(String id);

  Future<void> save(T entity);

  Future<void> delete(String id);

  /// Replaces the local entity with the authoritative cloud version.
  Future<void> markSynced(T entity);
}
