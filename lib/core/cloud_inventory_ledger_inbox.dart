import 'dart:async';
import 'dart:convert';

import 'package:stellar_pos/core/cloud_inventory_ledger_pull.dart';
import 'package:stellar_pos/core/cloud_inventory_movement.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// Durable inbox for supported remote ledger entities.
///
/// Receiving records never directly mutates local commercial repositories.
/// Entity-specific reconciliation must be idempotent and store-scoped.
abstract interface class CloudInventoryLedgerInboxStorage {
  Object? get(String key);
  Iterable<Object?> get values;
  Future<void> put(String key, Map<String, Object?> value);
  Future<void> flush();
}

/// A durable ledger record waiting for its store-scoped domain reconciler.
class CloudInventoryInboxEntry {
  const CloudInventoryInboxEntry({
    required this.storeId,
    required this.eventId,
    required this.entityId,
    required this.entityType,
    required this.operation,
    required this.version,
    required this.payload,
    this.status = 'pending',
    this.movement,
  });

  final String storeId;
  final String eventId;
  final String entityId;
  final String entityType;
  final String operation;
  final int version;
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
  Object? get(String key) => _cache[key];

  @override
  Iterable<Object?> get values => _cache.values;

  @override
  Future<void> put(String key, Map<String, Object?> value) async {
    final box = await _box;
    await box.put(key, value);
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

  static const Set<String> _supportedEntityTypes = <String>{
    'inventoryMovement',
    'purchase',
    'debtMovement',
    'electronicBalanceTransaction',
  };

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

  /// Returns durable, unapplied ledger records for one store in ledger order.
  ///
  /// This method never mutates stock, purchases, debts, or balances.
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
          final entityType = value['entityType'];
          final operation = value['operation'];
          final version = value['version'];
          final rawPayload = value['payload'];
          final rawMovement = value['movement'];
          final status = value['status'] ?? 'pending';

          if (eventId is! String ||
              entityId is! String ||
              entityType is! String ||
              !_supportedEntityTypes.contains(entityType) ||
              operation is! String ||
              operation != 'append' ||
              version is! int ||
              version < 1 ||
              rawPayload is! Map ||
              !<String>{'pending', 'applied'}.contains(status) ||
              eventId != '${entityType}_$entityId') {
            throw const FormatException('Registro del inbox del ledger inválido.');
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
          } else if (rawMovement != null) {
            throw const FormatException(
              'Una entidad comercial no puede contener un movimiento normalizado.',
            );
          }

          if (status == 'applied') continue;
          entries.add(CloudInventoryInboxEntry(
            storeId: storeId,
            eventId: eventId,
            entityId: entityId,
            entityType: entityType,
            operation: operation,
            version: version,
            payload: Map<String, dynamic>.from(rawPayload),
            status: status as String,
            movement: movement,
          ));
        }
        entries.sort((a, b) => a.version.compareTo(b.version));
        return List<CloudInventoryInboxEntry>.unmodifiable(entries);
      });

  /// Marks a record reconciled after its domain mutation is durably committed.
  ///
  /// Callers must first perform an idempotent, store-scoped domain operation.
  /// This status update alone never changes a business value.
  Future<void> markApplied({
    required String storeId,
    required String eventId,
  }) =>
      _serialize(() async {
        if (storeId.trim().isEmpty ||
            !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(storeId) ||
            eventId.trim().isEmpty ||
            !RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(eventId)) {
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
        final updated = Map<String, Object?>.from(raw)
          ..['status'] = 'applied';
        await _storage.put(key, updated);
        await _storage.flush();
      });

  /// Stores supported ledger records. Replaying identical content is a no-op;
  /// reusing an event ID for different content is a hard error.
  @override
  Future<void> apply(CloudInventoryLedgerChange change) =>
      _serialize(() async {
        final movement = change.movement;
        if (!_supportedEntityTypes.contains(change.entityType) ||
            change.storeId.trim().isEmpty ||
            change.version < 1 ||
            change.operation != 'append' ||
            change.payload['id'] != change.entityId ||
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
        // Event IDs are unique only within a store.
        final inboxKey = '${change.storeId}::${change.eventId}';
        final existing = _storage.get(inboxKey);
        if (existing != null) {
          if (existing is! Map) {
            throw StateError('Colisión de ID en el inbox del ledger.');
          }
          final comparableExisting = Map<String, Object?>.from(existing);
          final existingStatus = comparableExisting.remove('status');
          final comparableRecord = Map<String, Object?>.from(record)
            ..remove('status');
          if ((existingStatus != null &&
                  existingStatus != 'pending' &&
                  existingStatus != 'applied') ||
              jsonEncode(comparableExisting) != jsonEncode(comparableRecord)) {
            throw StateError('Colisión de ID en el inbox del ledger.');
          }
          // Preserve applied status on replay and verify durability before the
          // caller is allowed to acknowledge a retried ledger page.
          await _storage.flush();
          return;
        }
        await _storage.put(inboxKey, record);
        await _storage.flush();
      });
}
