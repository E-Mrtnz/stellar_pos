import 'package:cloud_functions/cloud_functions.dart';
import 'package:stellar_pos/core/cloud_inventory_movement.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

/// A single immutable ledger change returned by pullCloudLedgerChanges.
class CloudInventoryLedgerChange {
  const CloudInventoryLedgerChange({
    required this.storeId,
    required this.eventId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.version,
    required this.movement,
  });

  final String storeId;
  final String eventId;
  final String entityType;
  final String entityId;
  final String operation;
  final int version;
  final CloudInventoryMovement movement;

  factory CloudInventoryLedgerChange.fromMap(Map<String, dynamic> map) {
    if (map['storeId'] is! String ||
        map['eventId'] is! String ||
        map['entityType'] is! String ||
        map['entityId'] is! String ||
        map['operation'] is! String ||
        map['version'] is! int ||
        map['payload'] is! Map) {
      throw const FormatException('El cambio de inventario remoto está incompleto.');
    }
    final storeId = map['storeId'] as String;
    final entityId = map['entityId'] as String;
    final entityType = map['entityType'] as String;
    final operation = map['operation'] as String;
    if (entityType != 'inventoryMovement' || operation != 'append') {
      throw const FormatException('El cambio remoto no es un movimiento de inventario.');
    }
    final rawPayload = Map<String, dynamic>.from(map['payload'] as Map);
    // The server ledger schema uses business field names, not the local outbox
    // envelope. Reconstruct the domain movement explicitly at this boundary.
    if (rawPayload.keys.toSet().difference(
      <String>{'id', 'productId', 'quantityDelta', 'reason', 'createdAt'},
    ).isNotEmpty ||
        rawPayload.length != 5 ||
        rawPayload['id'] is! String ||
        rawPayload['productId'] is! String ||
        rawPayload['quantityDelta'] is! int ||
        rawPayload['reason'] is! String ||
        rawPayload['createdAt'] is! String) {
      throw const FormatException('El contenido del movimiento remoto es inválido.');
    }
    final occurredAt = DateTime.tryParse(rawPayload['createdAt'] as String);
    if (occurredAt == null) {
      throw const FormatException('La fecha del movimiento remoto es inválida.');
    }
    final movement = CloudInventoryMovement(
      movementId: rawPayload['id'] as String,
      storeId: storeId,
      productId: rawPayload['productId'] as String,
      delta: rawPayload['quantityDelta'] as int,
      reason: rawPayload['reason'] as String,
      occurredAt: occurredAt,
      // The ledger sequence is the authoritative cloud ordering cursor.
      // localVersion is device-local metadata and is not stored by the server.
      localVersion: 1,
    );
    if (movement.movementId != entityId ||
        map['eventId'] != 'inventoryMovement_$entityId' ||
        (map['version'] as int) < 1) {
      throw const FormatException('La identidad del movimiento remoto no coincide.');
    }
    final invalid = movement.validate(activeStoreId: storeId);
    if (invalid != null) {
      throw FormatException('Movimiento remoto inválido: $invalid.');
    }
    return CloudInventoryLedgerChange(
      storeId: storeId,
      eventId: map['eventId'] as String,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      version: map['version'] as int,
      movement: movement,
    );
  }
}

class CloudInventoryLedgerPage {
  const CloudInventoryLedgerPage({
    required this.storeId,
    required this.afterVersion,
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  final String storeId;
  final int afterVersion;
  final List<CloudInventoryLedgerChange> changes;
  final int nextCursor;
  final bool hasMore;
}

abstract interface class CloudInventoryLedgerPullTransport {
  Future<CloudInventoryLedgerPage> fetchPage({
    required String storeId,
    required int afterVersion,
    required int limit,
  });
}

class CloudFunctionsInventoryLedgerPullTransport
    implements CloudInventoryLedgerPullTransport {
  CloudFunctionsInventoryLedgerPullTransport({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<CloudInventoryLedgerPage> fetchPage({
    required String storeId,
    required int afterVersion,
    required int limit,
  }) async {
    final response = await _functions
        .httpsCallable('pullCloudLedgerChanges')
        .call(<String, Object?>{
      'storeId': storeId,
      'afterVersion': afterVersion,
      'limit': limit,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['storeId'] is! String ||
        data['afterVersion'] is! int ||
        data['nextCursor'] is! int ||
        data['hasMore'] is! bool ||
        data['changes'] is! List) {
      throw const FormatException('La página del ledger remoto es inválida.');
    }
    return CloudInventoryLedgerPage(
      storeId: data['storeId'] as String,
      afterVersion: data['afterVersion'] as int,
      nextCursor: data['nextCursor'] as int,
      hasMore: data['hasMore'] as bool,
      changes: (data['changes'] as List)
          .map((item) => CloudInventoryLedgerChange.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
    );
  }
}

/// The applier must durably deduplicate movementId before returning.
abstract interface class CloudInventoryLedgerChangeApplier {
  Future<void> apply(CloudInventoryLedgerChange change);
}

/// Validates a complete page, applies it, then commits its cursor. This
/// coordinator intentionally does not mutate Product.stock; the domain layer
/// must decide when a ledger movement can safely affect a local catalog.
class CloudInventoryLedgerPullCoordinator {
  CloudInventoryLedgerPullCoordinator({
    required CloudInventoryLedgerPullTransport transport,
    required CloudInventoryLedgerChangeApplier applier,
    required CloudSyncCursorStore cursors,
  })  : _transport = transport,
        _applier = applier,
        _cursors = cursors;

  final CloudInventoryLedgerPullTransport _transport;
  final CloudInventoryLedgerChangeApplier _applier;
  final CloudSyncCursorStore _cursors;

  Future<CloudInventoryLedgerPage> pullOnce({
    required String storeId,
    required String deviceId,
    int limit = 50,
  }) async {
    if (storeId.trim().isEmpty || storeId.contains('/') ||
        deviceId.trim().isEmpty || deviceId.contains('/')) {
      throw ArgumentError('storeId y deviceId deben ser identificadores válidos.');
    }
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'El límite debe estar entre 1 y 100.');
    }
    final current = await _cursors.read(storeId: storeId, deviceId: deviceId) ??
        CloudSyncCursor(storeId: storeId, version: 0);
    final page = await _transport.fetchPage(
      storeId: storeId,
      afterVersion: current.version,
      limit: limit,
    );
    if (page.storeId != storeId ||
        page.afterVersion != current.version ||
        page.nextCursor < current.version ||
        page.changes.length > limit) {
      throw const FormatException('La página del ledger no coincide con el cursor solicitado.');
    }
    var expectedVersion = current.version;
    for (final change in page.changes) {
      if (change.storeId != storeId || change.version != expectedVersion + 1) {
        throw const FormatException('El ledger remoto tiene versiones faltantes o de otra tienda.');
      }
      expectedVersion = change.version;
    }
    final expectedCursor = page.changes.isEmpty ? current.version : page.changes.last.version;
    if (page.nextCursor != expectedCursor) {
      throw const FormatException('El cursor del ledger no coincide con el último movimiento.');
    }
    for (final change in page.changes) {
      await _applier.apply(change);
    }
    if (page.nextCursor > current.version) {
      final advanced = await _cursors.advance(
        storeId: storeId,
        deviceId: deviceId,
        candidate: CloudSyncCursor(storeId: storeId, version: page.nextCursor),
      );
      if (!advanced) throw StateError('No se pudo guardar el cursor del ledger.');
    }
    return page;
  }
}
