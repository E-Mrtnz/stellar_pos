import 'dart:async';
import 'dart:convert';

import 'package:stellar_pos/core/cloud_ledger_sync.dart';

/// Durable receipt storage for local application of remote ledger entries.
/// Implementations should use a local database box dedicated to receipts.
abstract interface class CloudLedgerApplyReceiptStore {
  Object? get(String eventId);
  Future<void> put(String eventId, Object value);
  Future<void> flush();
}

/// A handler that applies one immutable ledger record to the local projection.
///
/// The handler MUST be idempotent by [CloudLedgerChange.eventId] (or by the
/// immutable entity ID) because a process can stop after the projection write
/// but before the receipt is persisted. Remote changes must never enqueue a
/// second outbound event.
typedef CloudLedgerChangeHandler = Future<void> Function(
  CloudLedgerChange change,
);

/// Concrete, durable dispatcher for the four server-accepted ledger types.
///
/// This class prevents already-receipted events from being applied twice and
/// persists a receipt only after the entity handler succeeds. It intentionally
/// does not invent repository-specific projection rules: inventory, purchases,
/// debts, and electronic balance each require an explicit handler supplied by
/// the composition root. Missing handlers fail closed.
class DurableCloudLedgerRemoteApplier implements CloudLedgerRemoteApplier {
  DurableCloudLedgerRemoteApplier({
    required CloudLedgerApplyReceiptStore receipts,
    required Map<CloudLedgerEntityType, CloudLedgerChangeHandler> handlers,
  })  : _receipts = receipts,
        _handlers = Map<CloudLedgerEntityType, CloudLedgerChangeHandler>.unmodifiable(
          handlers,
        );

  final CloudLedgerApplyReceiptStore _receipts;
  final Map<CloudLedgerEntityType, CloudLedgerChangeHandler> _handlers;
  Future<void> _tail = Future<void>.value();

  @override
  Future<void> apply(CloudLedgerChange change) {
    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        await _applySerialized(change);
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _applySerialized(CloudLedgerChange change) async {
    _validate(change);
    final existing = _receipts.get(change.eventId);
    if (existing != null) {
      if (existing is! Map ||
          existing['storeId'] != change.storeId ||
          existing['entityType'] != change.entityType.name ||
          existing['entityId'] != change.entityId ||
          existing['version'] != change.version ||
          existing['fingerprint'] != _fingerprint(change)) {
        throw StateError('El recibo local colisiona con otro cambio de ledger.');
      }
      return;
    }

    final handler = _handlers[change.entityType];
    if (handler == null) {
      throw StateError('No hay un applier local para ${change.entityType.name}.');
    }
    await handler(change);
    await _receipts.put(change.eventId, <String, Object?>{
      'storeId': change.storeId,
      'entityType': change.entityType.name,
      'entityId': change.entityId,
      'version': change.version,
      'fingerprint': _fingerprint(change),
      'appliedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await _receipts.flush();
  }

  void _validate(CloudLedgerChange change) {
    if (change.storeId.trim().isEmpty ||
        change.storeId.contains('/') ||
        change.eventId != '${change.entityType.name}_${change.entityId}' ||
        change.entityId.trim().isEmpty ||
        change.entityId.contains('/') ||
        change.version < 1 ||
        change.payload['id'] != change.entityId) {
      throw const FormatException('Cambio remoto incompatible con el applier local.');
    }
    jsonEncode(change.payload);
  }

  String _fingerprint(CloudLedgerChange change) =>
      jsonEncode(_canonical(change.payload));

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
