import 'dart:convert';

import 'package:stellar_pos/core/cloud_ledger_remote_applier.dart';
import 'package:stellar_pos/core/cloud_ledger_sync.dart';
import 'package:stellar_pos/core/data/repositories/debt_movement_repository.dart';
import 'package:stellar_pos/core/data/repositories/electronic_balance_transaction_repository.dart';
import 'package:stellar_pos/core/data/repositories/purchase_repository.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/models/purchase.dart';

/// Idempotent local upserts for immutable ledger records. Stock is deliberately
/// not projected here until movement storage and Product.stock can be recovered
/// atomically after an interrupted write.
class CloudLedgerRepositoryHandlers {
  CloudLedgerRepositoryHandlers({
    PurchaseRepository? purchases,
    DebtMovementRepository? debtMovements,
    ElectronicBalanceTransactionRepository? balanceTransactions,
    String inventoryMovementBox = 'cloud_inventory_movements',
  }) : _purchases = purchases ?? PurchaseRepository(),
       _debtMovements = debtMovements ?? DebtMovementRepository(),
       _balanceTransactions =
           balanceTransactions ?? ElectronicBalanceTransactionRepository(),
       _inventoryMovementBox = inventoryMovementBox;

  final PurchaseRepository _purchases;
  final DebtMovementRepository _debtMovements;
  final ElectronicBalanceTransactionRepository _balanceTransactions;
  final String _inventoryMovementBox;

  Map<CloudLedgerEntityType, CloudLedgerChangeHandler> get handlers =>
      <CloudLedgerEntityType, CloudLedgerChangeHandler>{
        CloudLedgerEntityType.inventoryMovement: _storeInventoryMovement,
        CloudLedgerEntityType.purchase: _upsertPurchase,
        CloudLedgerEntityType.debtMovement: _upsertDebtMovement,
        CloudLedgerEntityType.electronicBalanceTransaction: _upsertBalanceTransaction,
      };

  Future<void> _upsertPurchase(CloudLedgerChange change) async {
    final record = PurchaseRecord.fromMap(change.payload);
    _requireMatchingId(record.id, change.entityId);
    final existing = await _purchases.getById(record.id);
    if (existing != null) {
      _requireSameContent(existing.toMap(), record.toMap(), change.entityType);
      return;
    }
    await _purchases.save(record);
  }

  Future<void> _upsertDebtMovement(CloudLedgerChange change) async {
    final record = DebtMovement.fromMap(change.payload);
    _requireMatchingId(record.id, change.entityId);
    final existing = await _debtMovements.getById(record.id);
    if (existing != null) {
      _requireSameContent(existing.toMap(), record.toMap(), change.entityType);
      return;
    }
    await _debtMovements.save(record);
  }

  Future<void> _upsertBalanceTransaction(CloudLedgerChange change) async {
    final record = ElectronicBalanceTransaction.fromMap(change.payload);
    _requireMatchingId(record.id, change.entityId);
    final existing = await _balanceTransactions.getById(record.id);
    if (existing != null) {
      _requireSameContent(existing.toMap(), record.toMap(), change.entityType);
      return;
    }
    await _balanceTransactions.save(record);
  }

  Future<void> _storeInventoryMovement(CloudLedgerChange change) async {
    final movement = Map<String, dynamic>.from(change.payload);
    _requireMatchingId(movement['id']?.toString() ?? '', change.entityId);
    final productId = movement['productId'];
    final delta = movement['quantityDelta'];
    if (productId is! String ||
        productId.trim().isEmpty ||
        delta is! int ||
        delta == 0) {
      throw const FormatException('Movimiento de inventario local inválido.');
    }
    final box = await LocalStorage.openBox(_inventoryMovementBox);
    final existing = box.get(change.entityId);
    if (existing != null) {
      if (existing is! Map) {
        throw StateError('El movimiento local existente está corrupto.');
      }
      _requireSameContent(
        Map<String, dynamic>.from(existing),
        movement,
        change.entityType,
      );
      return;
    }
    await box.put(change.entityId, movement);
    await box.flush();
  }

  void _requireMatchingId(String actual, String expected) {
    if (actual.isEmpty || actual != expected) {
      throw const FormatException('El ID de la entidad no coincide con el evento.');
    }
  }

  void _requireSameContent(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
    CloudLedgerEntityType type,
  ) {
    if (_canonicalJson(existing) != _canonicalJson(incoming)) {
      throw StateError('Conflicto de contenido para ' + type.name + '.');
    }
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
