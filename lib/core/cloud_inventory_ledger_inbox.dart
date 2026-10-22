import 'dart:async';
import 'dart:convert';

import 'package:stellar_pos/core/cloud_inventory_ledger_pull.dart';
import 'package:stellar_pos/core/cloud_inventory_movement.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Durable inbox for remote movements. Receiving a movement does not directly
/// change Product.stock; a separate inventory-domain operation must reconcile
/// the inbox with the local catalog and mark the movement as applied.
abstract interface class CloudInventoryLedgerInboxStorage {
  Object? get(String eventId);
  Iterable<Object?> get values;
  Future<void> put(String eventId, Map<String, Object?> value);
  Future<void> flush();
}

/// A durable remote movement waiting for a future store-scoped stock reconciler.
class CloudInventoryInboxEntry {
  const CloudInventoryInboxEntry({
    required this.storeId,
    required this.eventId,
    required this.entityId,
    required this.version,
    required this.movement,
  });

  final String storeId;
  final String eventId;
  final String entityId;
  final int version;
  final CloudInventoryMovement movement;
}

class _HiveCloudInventoryLedgerInboxStorage
    implements CloudInventoryLedgerInboxStorage {
  _HiveCloudInventoryLedgerInboxStorage(this.boxName);
  final String boxName;

  Future<dynamic> get _box => LocalStorage.openBox(boxName);
  Map<String, Object?> _cache = <String, Object?>{};

  Future<void> _refresh() async {
    final box = await _box;
    _cache = <String, Object?>{
      for (final key in box.keys)
        if (key is String && box.get(key) is Map)
          key: Map<String, Object?>.from(box.get(key) as Map),
    };
  }

  @override
  Object? get(String eventId) => _cache[eventId];

  @override
  Iterable<Object?> get values => _cache.values;

  @override
  Future<void> put(String eventId, Map<String, Object?> value) async {
    final box = await _box;
    // Do not update the in-memory cache until flush succeeds. If persistence
    // fails, a retry must not mistake an uncommitted write for a durable inbox
    // record and allow the ledger cursor to advance.
    await box.put(eventId, value);
  }

  @override
  Future<void> flush() async {
    await (await _box).flush();
    await _refresh();
  }
}

class CloudInventoryLedgerInbox implements CloudInventoryLedgerChangeApplier {
  CloudInventoryLedgerInbox({
    this.boxName = 'cloud_inventory_ledger_inbox',
    CloudInventoryLedgerInboxStorage? storage,
  }) : _storage = storage ?? _HiveCloudInventoryLedgerInboxStorage(boxName);

  final String boxName;
  final CloudInventoryLedgerInboxStorage _storage;
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

  /// Returns durable movements awaiting reconciliation for one store.
  ///
  /// The inbox intentionally does not modify Product.stock. Consumers must
  /// reconcile entries through a store-scoped inventory domain operation.
  Future<List<CloudInventoryInboxEntry>> pendingForStore(String storeId) =>
      _serialize(() async {
        if (storeId.trim().isEmpty ||
            !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(storeId)) {
          throw ArgumentError.value(
            storeId,
            'storeId',
            'Identificador de tienda inválido.',
          );
        }
        if (_storage is _HiveCloudInventoryLedgerInboxStorage) {
          await _storage._refresh();
        }
        final entries = <CloudInventoryInboxEntry>[];
        for (final value in _storage.values) {
          if (value is! Map || value['storeId'] != storeId) continue;
          final eventId = value['eventId'];
          final entityId = value['entityId'];
          final version = value['version'];
          final rawMovement = value['movement'];
          if (eventId is! String ||
              entityId is! String ||
              version is! int ||
              version < 1 ||
              rawMovement is! Map) {
            throw const FormatException(
              'Registro del inbox de inventario inválido.',
            );
          }
          final movement = CloudInventoryMovement.fromPayload(
            Map<String, dynamic>.from(rawMovement),
            storeId: storeId,
          );
          if (eventId != 'inventoryMovement_${movement.movementId}' ||
              entityId != movement.movementId) {
            throw const FormatException(
              'La identidad del inbox de inventario no coincide.',
            );
          }
          entries.add(CloudInventoryInboxEntry(
            storeId: storeId,
            eventId: eventId,
            entityId: entityId,
            version: version,
            movement: movement,
          ));
        }
        entries.sort((a, b) => a.version.compareTo(b.version));
        return List<CloudInventoryInboxEntry>.unmodifiable(entries);
      });

  /// Stores only inventory movements. Replaying an identical event is a
  /// no-op; reusing an event ID for different content is a hard error.
  @override
  Future<void> apply(CloudInventoryLedgerChange change) =>
      _serialize(() async {
        final movement = change.movement;
        if (!change.isInventoryMovement || movement == null) {
          throw ArgumentError(
            'El inbox solo admite movimientos de inventario.',
          );
        }
        if (change.eventId != 'inventoryMovement_${movement.movementId}' ||
            change.entityId != movement.movementId ||
            change.storeId != movement.storeId ||
            change.version < 1) {
          throw const FormatException(
            'La identidad del movimiento del inbox no coincide.',
          );
        }
        if (_storage is _HiveCloudInventoryLedgerInboxStorage) {
          await _storage._refresh();
        }
        final record = <String, Object?>{
          'storeId': change.storeId,
          'eventId': change.eventId,
          'entityType': change.entityType,
          'entityId': change.entityId,
          'version': change.version,
          'movement': movement.toPayload(),
        };
        // Movement IDs are unique only within a store; scope inbox keys to
        // avoid collisions when stores independently create the same event ID.
        final inboxKey = '${change.storeId}::${change.eventId}';
        final existing = _storage.get(inboxKey);
        if (existing != null) {
          if (existing is! Map ||
              jsonEncode(existing) != jsonEncode(record)) {
            throw StateError('Colisión de ID en el inbox de inventario.');
          }
          // A prior attempt may have written to Hive but failed while flushing.
          // Re-flush an identical replay before allowing the cursor to advance.
          await _storage.flush();
          return;
        }
        await _storage.put(inboxKey, record);
        await _storage.flush();
      });
}
