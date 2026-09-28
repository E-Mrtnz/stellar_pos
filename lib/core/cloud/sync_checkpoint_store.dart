import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Persists the last successful cloud cursor per store/collection.
class SyncCheckpointStore {
  static const _boxName = 'cloud_sync_checkpoints';

  Future<DateTime?> get({
    required String storeId,
    required String collection,
  }) async {
    final box = await LocalStorage.openBox(_boxName);
    final value = box.get(_key(storeId, collection));
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  }

  Future<void> save({
    required String storeId,
    required String collection,
    required DateTime timestamp,
  }) async {
    final box = await LocalStorage.openBox(_boxName);
    await box.put(
      _key(storeId, collection),
      timestamp.toUtc().toIso8601String(),
    );
  }

  Future<void> clear({
    required String storeId,
    required String collection,
  }) async {
    final box = await LocalStorage.openBox(_boxName);
    await box.delete(_key(storeId, collection));
  }

  String _key(String storeId, String collection) => '$storeId::$collection';
}
