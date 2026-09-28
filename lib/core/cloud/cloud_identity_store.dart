import 'package:stellar_pos/core/data/storage/local_storage.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

/// Stores the stable device identity and the store/tenant selected for sync.
///
/// The store id is intentionally explicit: generating one automatically per
/// device would prevent two devices from sharing the same business data.
class CloudIdentityStore {
  static const _boxName = 'cloud_sync_identity';
  static const _deviceIdKey = 'deviceId';
  static const _storeIdKey = 'storeId';

  Future<String> getOrCreateDeviceId() async {
    final box = await LocalStorage.openBox(_boxName);
    final existing = box.get(_deviceIdKey)?.toString().trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final deviceId = IdGenerator.newId();
    await box.put(_deviceIdKey, deviceId);
    return deviceId;
  }

  Future<String?> getStoreId() async {
    final box = await LocalStorage.openBox(_boxName);
    final value = box.get(_storeIdKey)?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> setStoreId(String storeId) async {
    final normalized = storeId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(storeId, 'storeId', 'cannot be empty');
    }
    final box = await LocalStorage.openBox(_boxName);
    await box.put(_storeIdKey, normalized);
  }

  Future<void> clearStoreId() async {
    final box = await LocalStorage.openBox(_boxName);
    await box.delete(_storeIdKey);
  }
}
