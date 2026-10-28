import 'dart:convert';

import 'package:stellar_pos/core/cloud_ledger_remote_applier.dart';
import 'package:stellar_pos/core/cloud_ledger_sync.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Minimal persistence contract for a store-scoped ledger projection.
abstract interface class CloudLedgerProjectionStorage {
  Future<Object?> get(String entityId);
  Future<void> put(String entityId, Map<String, dynamic> payload);
  Future<void> flush();
}

typedef CloudLedgerProjectionStorageFactory = Future<CloudLedgerProjectionStorage>
    Function(String boxName);

class _HiveCloudLedgerProjectionStorage implements CloudLedgerProjectionStorage {
  _HiveCloudLedgerProjectionStorage(this.boxName);

  final String boxName;
  Future<dynamic> get _box => LocalStorage.openBox(boxName);

  @override
  Future<Object?> get(String entityId) async => (await _box).get(entityId);

  @override
  Future<void> put(String entityId, Map<String, dynamic> payload) async {
    await (await _box).put(entityId, payload);
  }

  @override
  Future<void> flush() async => (await _box).flush();
}

/// Stores remote ledger records in per-store Hive projections. These records
/// are deliberately not merged into the app's global business repositories:
/// those boxes are not store-scoped yet. Inventory movements remain immutable
/// and do not directly overwrite Product.stock.
class CloudLedgerRepositoryHandlers {
  CloudLedgerRepositoryHandlers({
    String projectionBoxPrefix = 'cloud_ledger_projection',
    CloudLedgerProjectionStorageFactory? storageFactory,
  }) : _projectionBoxPrefix = projectionBoxPrefix,
       _storageFactory = storageFactory ?? _openHiveProjection;

  final String _projectionBoxPrefix;
  final CloudLedgerProjectionStorageFactory _storageFactory;

  static Future<CloudLedgerProjectionStorage> _openHiveProjection(
    String boxName,
  ) async {
    await LocalStorage.openBox(boxName);
    return _HiveCloudLedgerProjectionStorage(boxName);
  }

  Map<CloudLedgerEntityType, CloudLedgerChangeHandler> get handlers =>
      <CloudLedgerEntityType, CloudLedgerChangeHandler>{
        for (final type in CloudLedgerEntityType.values)
          type: (change) => _storeProjection(type, change),
      };

  Future<void> _storeProjection(
    CloudLedgerEntityType type,
    CloudLedgerChange change,
  ) async {
    if (change.storeId.trim().isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(change.storeId) ||
        change.entityId.trim().isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(change.entityId) ||
        change.eventId != '${type.name}_${change.entityId}' ||
        change.payload['id'] != change.entityId) {
      throw const FormatException('Identidad de ledger local inválida.');
    }
    final boxName = '${_projectionBoxPrefix}_${type.name}_${change.storeId}';
    final storage = await _storageFactory(boxName);
    final existing = await storage.get(change.entityId);
    final incoming = Map<String, dynamic>.from(change.payload);
    if (existing != null) {
      if (existing is! Map ||
          _canonicalJson(Map<String, dynamic>.from(existing)) !=
              _canonicalJson(incoming)) {
        throw StateError('Conflicto de contenido para ${type.name}.');
      }
      return;
    }
    await storage.put(change.entityId, incoming);
    await storage.flush();
  }

  String _canonicalJson(Object? value) => jsonEncode(_canonical(value));

  Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _canonical(value[key]),
      };
    }
    if (value is List) return value.map(_canonical).toList(growable: false);
    return value;
  }
}
