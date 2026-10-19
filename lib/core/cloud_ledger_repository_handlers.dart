import 'dart:convert';

import 'package:stellar_pos/core/cloud_ledger_remote_applier.dart';
import 'package:stellar_pos/core/cloud_ledger_sync.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Stores remote ledger records in per-store Hive projections. These records
/// are deliberately not merged into the app's global business repositories:
/// those boxes are not store-scoped yet. Inventory movements remain immutable
/// and do not directly overwrite Product.stock.
class CloudLedgerRepositoryHandlers {
  CloudLedgerRepositoryHandlers({
    String projectionBoxPrefix = 'cloud_ledger_projection',
  }) : _projectionBoxPrefix = projectionBoxPrefix;

  final String _projectionBoxPrefix;

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
        change.storeId.contains('/') ||
        change.entityId.trim().isEmpty ||
        change.entityId.contains('/') ||
        change.payload['id'] != change.entityId) {
      throw const FormatException('Identidad de ledger local inválida.');
    }
    final boxName = '${_projectionBoxPrefix}_${type.name}_${change.storeId}';
    final box = await LocalStorage.openBox(boxName);
    final existing = box.get(change.entityId);
    final incoming = Map<String, dynamic>.from(change.payload);
    if (existing != null) {
      if (existing is! Map ||
          _canonicalJson(Map<String, dynamic>.from(existing)) !=
              _canonicalJson(incoming)) {
        throw StateError('Conflicto de contenido para ' + type.name + '.');
      }
      return;
    }
    await box.put(change.entityId, incoming);
    await box.flush();
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
