import 'package:hive_ce/hive_ce.dart';

import 'package:stellar_pos/core/data/storage/local_storage.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';

/// Owns the on-disk schema version for local application data.
///
/// Schema changes must be explicit and sequential. A migration is applied
/// before its version is persisted, so a failed migration is never recorded as
/// completed. Version 1 is the initial persisted format and therefore has no
/// data migration steps yet.
class StorageSchema {
  const StorageSchema._();

  static const int currentVersion = 1;
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
      await _runMigration(box, version, nextVersion);
      await box.put(_versionKey, nextVersion);
      version = nextVersion;
    }
  }

  static Future<void> _runMigration(
    Box<dynamic> box,
    int fromVersion,
    int toVersion,
  ) async {
    // No migration is required for version 1.
    // Add explicit `fromVersion -> toVersion` steps here as the data model evolves.
    throw StateError(
      'No existe una migración de almacenamiento definida de $fromVersion a $toVersion.',
    );
  }
}
