import 'dart:async';
import 'dart:convert';

import 'package:stellar_pos/core/cloud_inventory_ledger_pull.dart';
import 'package:stellar_pos/core/cloud_inventory_movement.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Durable inbox for supported remote ledger entities.
///
/// Receiving records never directly mutates the local commercial repositories.
/// Entity-specific reconciliation must be implemented separately and must be
/// idempotent before it changes stock, purchases, debts, or balances.
abstract interface class CloudInventoryLedgerInboxStorage {
  Object? get(String eventId);
  Iterable<Object?> get values;
  Future<void> put(String eventId, Map<String, Object?> value);
  Future<void> flush();
}

/// A durable ledger record waiting for its store-scoped domain reconciler.
class CloudInventoryInboxEntry {
  const CloudInventoryInboxEntry({
    required this.storeId,
    required this.eventId,
    required this.entityId,
    required this.version,
    required this.entityType,
    required this.operation,
    required this.payload,
    this.status = 'pending',
    this.movement,
  });

  final String storeId;
  final String eventId;
  final String entityId;
  final int version;
  final String entityType;
  final String operation;
  final Map<String, dynamic> payload;
  final String status;
  final CloudInventoryMovement? movement;
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

  /// Returns durable ledger records awaiting reconciliation for one store.
  ///
  /// The inbox intentionally does not mutate commercial data. Consumers must
  /// dispatch each record to an idempotent store-scoped domain operation.
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
          final entityType = value['entityType'];
          final operation = value['operation'];
          final status = value['status'] ?? 'pending';
          final rawPayload = value['payload'];
          final rawMovement = value['movement'];
          const supportedEntityTypes = <String>{
            'inventoryMovement',
            'purchase',
            'debtMovement',
            'electronicBalanceTransaction',
          };
          if (eventId is! String ||
              entityId is! String ||
              entityType is! String ||
              !supportedEntityTypes.contains(entityType) ||
              operation is! String ||
              operation != 'append' ||
              status is! String ||
              !<String>{'pending', 'applied'}.contains(status) ||
              version is! int ||
              version < 1 ||
              rawPayload is! Map ||
              eventId != '${entityType}_$entityId') {
            throw const FormatException(
              'Registro del inbox del ledger inválido.',
            );
          }
          CloudInventoryMovement? movement;
          if (entityType == 'inventoryMovement') {
            if (rawMovement is! Map) {
              throw const FormatException(
                'Falta el movimiento de inventario normalizado.',
              );
            }
            movement = CloudInventoryMovement.fromPayload(
              Map<String, dynamic>.from(rawMovement),
              storeId: storeId,
            );
            if (eventId != 'inventoryMovement_${movement.movementId}' ||
                entityId != movement.movementId) {
              throw const FormatException(
                'La identidad del movimiento del inbox no coincide.',
              );
            }
          }
          if (status == 'applied') continue;
          entries.add(CloudInventoryInboxEntry(
            storeId: storeId,
            eventId: eventId,
            entityId: entityId,
            version: version,
            entityType: entityType,
            operation: operation,
            payload: Map<String, dynamic>.from(rawPayload),
            status: status,
            movement: movement,
          ));
        }
        entries.sort((a, b) => a.version.compareTo(b.version));
        return List<CloudInventoryInboxEntry>.unmodifiable(entries);
      });

  /// Marks a record reconciled after its domain mutation is durably committed.
  ///
  /// Callers must first perform an idempotent store-scoped transaction. This
  /// status update alone never changes stock or any other business value.
  Future<void> markApplied({
    required String storeId,
    required String eventId,
  }) => _serialize(() async {
    if (storeId.trim().isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]{1,80}  /// reusing an event ID for different content is a hard error.
  @override
  Future<void> apply(CloudInventoryLedgerChange change) =>
      _serialize(() async {
        final movement = change.movement;
        const supportedEntityTypes = <String>{
          'inventoryMovement',
          'purchase',
          'debtMovement',
          'electronicBalanceTransaction',
        };
        if (!supportedEntityTypes.contains(change.entityType) ||
            change.storeId.trim().isEmpty ||
            change.version < 1 ||
            change.eventId != '${change.entityType}_${change.entityId}') {
          throw const FormatException(
            'La identidad o el tipo del registro del inbox no coincide.',
          );
        }
        if (change.isInventoryMovement &&
            (movement == null ||
                change.entityId != movement.movementId ||
                change.storeId != movement.storeId)) {
          throw const FormatException(
            'La identidad del movimiento del inbox no coincide.',
          );
        }
        if (!change.isInventoryMovement && movement != null) {
          throw const FormatException(
            'Una entidad comercial no puede contener un movimiento normalizado.',
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
          'operation': change.operation,
          'version': change.version,
          'status': 'pending',
          'payload': change.payload,
          'movement': movement?.toPayload(),
        };
        // Movement IDs are unique only within a store; scope inbox keys to
        // avoid collisions when stores independently create the same event ID.
        final inboxKey = '${change.storeId}::${change.eventId}';
        final existing = _storage.get(inboxKey);
        if (existing != null) {
          if (existing is! Map ||
              jsonEncode(existing) != jsonEncode(record)) {
            throw StateError('Colisión de ID en el inbox del ledger.');
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
).hasMatch(storeId) ||
        eventId.trim().isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]{1,200}  /// reusing an event ID for different content is a hard error.
  @override
  Future<void> apply(CloudInventoryLedgerChange change) =>
      _serialize(() async {
        final movement = change.movement;
        const supportedEntityTypes = <String>{
          'inventoryMovement',
          'purchase',
          'debtMovement',
          'electronicBalanceTransaction',
        };
        if (!supportedEntityTypes.contains(change.entityType) ||
            change.storeId.trim().isEmpty ||
            change.version < 1 ||
            change.eventId != '${change.entityType}_${change.entityId}') {
          throw const FormatException(
            'La identidad o el tipo del registro del inbox no coincide.',
          );
        }
        if (change.isInventoryMovement &&
            (movement == null ||
                change.entityId != movement.movementId ||
                change.storeId != movement.storeId)) {
          throw const FormatException(
            'La identidad del movimiento del inbox no coincide.',
          );
        }
        if (!change.isInventoryMovement && movement != null) {
          throw const FormatException(
            'Una entidad comercial no puede contener un movimiento normalizado.',
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
          'operation': change.operation,
          'version': change.version,
          'status': 'pending',
          'payload': change.payload,
          'movement': movement?.toPayload(),
        };
        // Movement IDs are unique only within a store; scope inbox keys to
        // avoid collisions when stores independently create the same event ID.
        final inboxKey = '${change.storeId}::${change.eventId}';
        final existing = _storage.get(inboxKey);
        if (existing != null) {
          if (existing is! Map ||
              jsonEncode(existing) != jsonEncode(record)) {
            throw StateError('Colisión de ID en el inbox del ledger.');
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
).hasMatch(eventId)) {
      throw ArgumentError('Identificador de tienda o evento inválido.');
    }
    if (_storage is _HiveCloudInventoryLedgerInboxStorage) {
      await _storage._refresh();
    }
    final key = '$storeId::$eventId';
    final raw = _storage.get(key);
    if (raw is! Map ||
        raw['storeId'] != storeId ||
        raw['eventId'] != eventId) {
      throw StateError('No existe el registro del ledger solicitado.');
    }
    if (raw['status'] == 'applied') return;
    if (raw['status'] != null && raw['status'] != 'pending') {
      throw StateError('El estado del registro del ledger es inválido.');
    }
    final updated = Map<String, Object?>.from(raw)..['status'] = 'applied';
    await _storage.put(key, updated);
    await _storage.flush();
  });

  /// Stores supported ledger records. Replaying identical content is a no-op;
  /// reusing an event ID for different content is a hard error.
  @override
  Future<void> apply(CloudInventoryLedgerChange change) =>
      _serialize(() async {
        final movement = change.movement;
        const supportedEntityTypes = <String>{
          'inventoryMovement',
          'purchase',
          'debtMovement',
          'electronicBalanceTransaction',
        };
        if (!supportedEntityTypes.contains(change.entityType) ||
            change.storeId.trim().isEmpty ||
            change.version < 1 ||
            change.eventId != '${change.entityType}_${change.entityId}') {
          throw const FormatException(
            'La identidad o el tipo del registro del inbox no coincide.',
          );
        }
        if (change.isInventoryMovement &&
            (movement == null ||
                change.entityId != movement.movementId ||
                change.storeId != movement.storeId)) {
          throw const FormatException(
            'La identidad del movimiento del inbox no coincide.',
          );
        }
        if (!change.isInventoryMovement && movement != null) {
          throw const FormatException(
            'Una entidad comercial no puede contener un movimiento normalizado.',
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
          'operation': change.operation,
          'version': change.version,
          'status': 'pending',
          'payload': change.payload,
          'movement': movement?.toPayload(),
        };
        // Movement IDs are unique only within a store; scope inbox keys to
        // avoid collisions when stores independently create the same event ID.
        final inboxKey = '${change.storeId}::${change.eventId}';
        final existing = _storage.get(inboxKey);
        if (existing != null) {
          if (existing is! Map ||
              jsonEncode(existing) != jsonEncode(record)) {
            throw StateError('Colisión de ID en el inbox del ledger.');
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
