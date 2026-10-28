import 'dart:convert';

import 'package:stellar_pos/core/cloud_sale_acceptance_transport.dart';
import 'package:stellar_pos/core/cloud_sales_pull.dart';
import 'package:stellar_pos/core/cloud_sync_worker.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Explicit, caller-triggered bridge between a locally saved sale and the
/// idempotent server acceptance endpoint. It is not scheduled automatically.
class CloudSaleSyncCoordinator {
  CloudSaleSyncCoordinator({
    required CloudSaleAcceptanceGateway acceptance,
    required CloudSaleLocalStore local,
    required CloudSyncSessionGate sessionGate,
  }) : _acceptance = acceptance, _local = local, _sessionGate = sessionGate;

  final CloudSaleAcceptanceGateway _acceptance;
  final CloudSaleLocalStore _local;
  final CloudSyncSessionGate _sessionGate;

  Future<CloudSaleAcceptance> acceptSale({
    required String storeId,
    required String saleId,
  }) async {
    if (storeId.trim().isEmpty || storeId.contains('/') ||
        saleId.trim().isEmpty || saleId.contains('/')) {
      throw ArgumentError('storeId y saleId deben ser identificadores válidos.');
    }
    if (!await _sessionGate.canSyncStore(storeId)) {
      throw StateError('La tienda no tiene una sesión y membresía activas.');
    }
    final original = await _local.getById(saleId);
    if (original == null) throw StateError('La venta local no existe.');
    if (!original.isCompleted) throw StateError('Solo se pueden sincronizar ventas completadas.');

    // If the server accepted the sale but the local save later failed, the same
    // stable sale ID makes the next call a safe duplicate replay.
    final accepted = await _acceptance.accept(storeId: storeId, sale: original);
    final current = await _local.getById(saleId);
    if (current == null || _businessFingerprint(current) != _businessFingerprint(original)) {
      throw StateError(
        'La venta cambió durante la sincronización. Se requiere reconciliación; no se sobrescribió el registro local.',
      );
    }
    final now = DateTime.now().toUtc();
    final metadata = current.metadata;
    final synced = SyncMetadata(
      createdAt: metadata.createdAt,
      updatedAt: metadata.updatedAt,
      version: metadata.version,
      schemaVersion: metadata.schemaVersion,
      syncState: SyncState.synced,
      lastSyncedAt: now,
      deletedAt: metadata.deletedAt,
      deviceId: metadata.deviceId,
      storeId: storeId,
    );
    await _local.save(current.copyWith(
      saleNumber: accepted.saleNumber,
      ticketNumber: accepted.ticketNumber,
      metadata: synced,
    ));
    return accepted;
  }

  String _businessFingerprint(SaleRecord sale) {
    final data = Map<String, dynamic>.from(sale.toMap())
      ..remove('ticketNumber')
      ..remove('saleNumber')
      ..remove('metadata');
    return _canonical(data);
  }

  String _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
    }
    if (value is List) return '[${value.map(_canonical).join(',')}]';
    return jsonEncode(value);
  }
}
