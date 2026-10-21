import 'dart:async';
import 'dart:convert';

import 'package:stellar_pos/core/cloud_inventory_ledger_pull.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Durable inbox for remote movements. Receiving a movement does not directly
/// change Product.stock; a separate inventory-domain operation must reconcile
/// the inbox with the local catalog and mark the movement as applied.
abstract interface class CloudInventoryLedgerInboxStorage {
  Object? get(String eventId);
  Future<void> put(String eventId, Map<String, Object?> value);
  Future<void> flush();
}

class _HiveCloudInventoryLedgerInboxStorage
    implements CloudInventoryLedgerInboxStorage {
  _HiveCloudInventoryLedgerInboxStorage(this.boxName);
  final String boxName;

  Future<dynamic> get _box => LocalStorage.openBox(boxName);

  @override
  Object? get(String eventId) => _cache[eventId];

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

  /// Stores only inventory movements. Replaying an identical event is a
  /// no-op; reusing an event ID for different content is a hard error.
  @override
  Future<void> apply(CloudInventoryLedgerChange change) => _serialize(() async {
    final movement = change.movement;
    if (!change.isInventoryMovement || movement == null) {
      throw ArgumentError('El inbox solo admite movimientos de inventario.');
    }
    if (change.eventId != 'inventoryMovement_${movement.movementId}' ||
        change.entityId != movement.movementId ||
        change.storeId != movement.storeId ||
        change.version < 1) {
      throw const FormatException('La identidad del movimiento del inbox no coincide.');
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
    final existing = _storage.get(change.eventId);
    if (existing != null) {
      if (existing is! Map ||
          jsonEncode(existing) != jsonEncode(record)) {
        throw StateError('Colisión de ID en el inbox de inventario.');
      }
      // A prior attempt may have written to Hive but failed while flushing.
      // Re-flush an identical replay before allowing the caller to advance its
      // ledger cursor.
      await _storage.flush();
      return;
    }
    await _storage.put(change.eventId, record);
    await _storage.flush();
  });
}
