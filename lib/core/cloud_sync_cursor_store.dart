import 'dart:async';

import 'package:stellar_pos/core/cloud_sync_protocol.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Hive-backed cursor storage scoped by both store and device.
///
/// The cursor is committed only after a caller has durably applied every
/// change in the corresponding page. This class never fetches or applies data.
abstract interface class CloudSyncCursorStorage {
  Object? get(String key);
  Future<void> put(String key, Object value);
  Future<void> flush();
}

class _HiveCursorStorage implements CloudSyncCursorStorage {
  _HiveCursorStorage(this.boxName);
  final String boxName;
  Future<dynamic> get box => LocalStorage.openBox(boxName);
  Map<String, Object?> cache = <String, Object?>{};

  Future<void> refresh() async {
    final opened = await box;
    cache = <String, Object?>{
      for (final key in opened.keys) key as String: opened.get(key) as Object?,
    };
  }

  @override
  Object? get(String key) => cache[key];

  @override
  Future<void> put(String key, Object value) async {
    final opened = await box;
    // Keep the committed cache unchanged until flush succeeds. If the Hive
    // write reaches the in-memory box but persistence fails, callers must not
    // observe an advanced cursor and skip unapplied remote events.
    await opened.put(key, value);
  }

  @override
  Future<void> flush() async {
    await (await box).flush();
    await refresh();
  }
}

class CloudSyncCursorStore {
  CloudSyncCursorStore({
    this.boxName = 'cloud_sync_cursors',
    CloudSyncCursorStorage? storage,
  }) : _storage = storage ?? _HiveCursorStorage(boxName);

  final String boxName;
  final CloudSyncCursorStorage _storage;

  // Cursor stores may be created independently by different coordinators. Share
  // the serialization queue by Hive box so concurrent advances cannot race on
  // stale reads and overwrite a newer durable cursor with an older version.
  static final Map<String, Future<void>> _tailsByBox = <String, Future<void>>{};

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = Completer<T>();
    final previous = _tailsByBox[boxName] ?? Future<void>.value();
    final next = previous.then((_) async {
      try {
        result.complete(await action());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    _tailsByBox[boxName] = next;
    return result.future;
  }

  String _key(String storeId, String deviceId) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(storeId) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(deviceId)) {
      throw ArgumentError('storeId y deviceId deben ser identificadores válidos.');
    }
    return '$deviceId::$storeId';
  }

  Future<CloudSyncCursor?> read({
    required String storeId,
    required String deviceId,
  }) => _serialize(() async {
    if (_storage is _HiveCursorStorage) await _storage.refresh();
    final raw = _storage.get(_key(storeId, deviceId));
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
    _key(storeId, deviceId);
    if (candidate.storeId != storeId || candidate.version < 0) return false;
    if (_storage is _HiveCursorStorage) await _storage.refresh();
    final key = _key(storeId, deviceId);
    final raw = _storage.get(key);
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
    await _storage.put(key, <String, Object?>{
      'storeId': storeId,
      'deviceId': deviceId,
      'version': candidate.version,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await _storage.flush();
    return true;
  });
}
