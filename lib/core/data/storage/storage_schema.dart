import 'package:hive_ce/hive_ce.dart';

import 'package:stellar_pos/core/data/storage/local_storage.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';

/// Owns the on-disk schema version for local application data.
///
/// Schema changes must be explicit and sequential. A migration is applied
/// before its version is persisted, so a failed migration is never recorded as
/// completed.
class StorageSchema {
  const StorageSchema._();

  static const int currentVersion = 4;
  static const String _versionKey = 'schemaVersion';

  static Future<void> initialize() async {
    final box = await LocalStorage.openBox(StorageBoxes.storageMetadata);
    final storedVersion = _readVersion(box);

    if (storedVersion == null) {
      await box.put(_versionKey, currentVersion);
      return;
    }

    if (storedVersion > currentVersion) {
      throw StateError(
        'La versión de almacenamiento ($storedVersion) es más nueva que la compatible ($currentVersion).',
      );
    }

    if (storedVersion == currentVersion) return;

    await _migrate(box, storedVersion, currentVersion);
  }

  static int? _readVersion(Box<dynamic> box) {
    final value = box.get(_versionKey);
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw StateError('La versión de almacenamiento local no es válida.');
  }

  static Future<void> _migrate(
    Box<dynamic> box,
    int fromVersion,
    int toVersion,
  ) async {
    var version = fromVersion;
    while (version < toVersion) {
      final nextVersion = version + 1;
      await _runMigration(version, nextVersion);
      await box.put(_versionKey, nextVersion);
      version = nextVersion;
    }
  }

  static Future<void> _runMigration(int fromVersion, int toVersion) async {
    // Versions 2, 3 and 4 were used only by the temporary TIGO balance
    // correction attempts. Those corrections were intentionally reverted, so
    // upgrading between these historical markers is now a data-preserving
    // no-op. No existing application data is modified.
    if (fromVersion >= 1 &&
        fromVersion <= 3 &&
        toVersion == fromVersion + 1) {
      return;
    }

    throw StateError(
      'No existe una migración de almacenamiento definida de $fromVersion a $toVersion.',
    );
  }
}
