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

  static const int currentVersion = 2;
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
    if (fromVersion == 0 && toVersion == 1) return;

    if (fromVersion == 1 && toVersion == 2) {
      final accountsBox = await LocalStorage.openBox(
        StorageBoxes.electronicBalanceAccounts,
      );

      for (final key in accountsBox.keys) {
        final raw = accountsBox.get(key);
        if (raw is! Map) continue;

        final map = Map<String, dynamic>.from(raw);
        final companyName = map['companyName']?.toString().trim().toLowerCase();
        final balance = map['balance'];

        if (companyName != 'tigo') continue;

        final currentBalance = balance is num
            ? balance.toDouble()
            : double.tryParse(balance?.toString() ?? '');

        // One-time correction for the known $0.12 data-entry discrepancy:
        // $25.52 was recorded instead of the actual $25.40.
        if (currentBalance != null && (currentBalance - 25.52).abs() < 0.000001) {
          map['balance'] = 25.40;
          await accountsBox.put(key, map);
        }
      }
      return;
    }

    throw StateError(
      'No existe una migración de almacenamiento definida de $fromVersion a $toVersion.',
    );
  }
}
