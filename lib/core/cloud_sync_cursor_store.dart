import 'dart:async';

import 'package:stellar_pos/core/cloud_sync_protocol.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Hive-backed cursor storage scoped by both store and device.
///
/// The cursor is committed only after a caller has durably applied every
/// change in the corresponding page. This class never fetches or applies data.
class CloudSyncCursorStore {
  CloudSyncCursorStore({this.boxName = 'cloud_sync_cursors'});

  final String boxName;
  Future<void> _tail = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await action());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  String _key(String storeId, String deviceId) {
    if (storeId.trim().isEmpty || storeId.contains('/') ||
        deviceId.trim().isEmpty || deviceId.contains('/')) {
      throw ArgumentError('storeId y deviceId deben ser segmentos no vacíos.');
    }
    return '$deviceId::$storeId';
  }

  Future<CloudSyncCursor?> read({
    required String storeId,
    required String deviceId,
  }) => _serialize(() async {
    final box = await LocalStorage.openBox(boxName);
    final raw = box.get(_key(storeId, deviceId));
    if (raw == null) return null;
    if (raw is! Map || raw['storeId'] != storeId ||
        raw['deviceId'] != deviceId || raw['version'] is! int ||
        (raw['version'] as int) < 0) {
      throw StateError('El cursor local de sincronización está corrupto.');
    }
    return CloudSyncCursor(
      storeId: storeId,
      version: raw['version'] as int,
    );
  });

  /// Persists a monotonic cursor. Returns false for a cross-store or backward
  /// update and leaves the durable value unchanged.
  Future<bool> advance({
    required String storeId,
    required String deviceId,
    required CloudSyncCursor candidate,
  }) => _serialize(() async {
    _key(storeId, deviceId); // Validate both scope segments.
    if (candidate.storeId != storeId || candidate.version < 0) return false;
    final box = await LocalStorage.openBox(boxName);
    final key = _key(storeId, deviceId);
    final raw = box.get(key);
    if (raw != null) {
      if (raw is! Map || raw['storeId'] != storeId ||
          raw['deviceId'] != deviceId || raw['version'] is! int ||
          (raw['version'] as int) < 0) {
        throw StateError('El cursor local de sincronización está corrupto.');
      }
      final currentVersion = raw['version'] as int;
      if (candidate.version < currentVersion) return false;
      if (candidate.version == currentVersion) return true;
    }
    await box.put(key, <String, Object?>{
      'storeId': storeId,
      'deviceId': deviceId,
      'version': candidate.version,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await box.flush();
    return true;
  });
}
