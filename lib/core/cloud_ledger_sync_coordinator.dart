import 'package:stellar_pos/core/cloud_ledger_sync.dart';
import 'package:stellar_pos/core/cloud_sync_worker.dart';

/// Explicit single-entry ledger acceptance. This is intentionally not wired to
/// checkout or the background scheduler: callers must opt in and supply a
/// previously persisted immutable local record with a stable ID.
class CloudLedgerSyncCoordinator {
  CloudLedgerSyncCoordinator({
    required CloudLedgerGateway gateway,
    required CloudSyncSessionGate sessionGate,
  }) : _gateway = gateway, _sessionGate = sessionGate;

  final CloudLedgerGateway _gateway;
  final CloudSyncSessionGate _sessionGate;

  Future<CloudLedgerAcceptance> append({
    required String storeId,
    required CloudLedgerEntityType entityType,
    required String entityId,
    required Map<String, dynamic> entry,
  }) async {
    if (storeId.trim().isEmpty ||
        storeId.contains('/') ||
        entityId.trim().isEmpty ||
        entityId.contains('/') ||
        entry['id'] != entityId) {
      throw ArgumentError('La tienda y la entidad deben tener IDs estables válidos.');
    }
    if (!await _sessionGate.canSyncStore(storeId)) {
      throw StateError('La tienda no tiene una sesión y membresía activas.');
    }
    return _gateway.append(
      storeId: storeId,
      entityType: entityType,
      entityId: entityId,
      entry: entry,
    );
  }
}
