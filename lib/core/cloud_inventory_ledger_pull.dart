import 'package:cloud_functions/cloud_functions.dart';
import 'package:stellar_pos/core/cloud_inventory_movement.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

/// One append-only entry from the store-wide cloud ledger.
class CloudInventoryLedgerChange {
  const CloudInventoryLedgerChange({
    required this.storeId,
    required this.eventId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.version,
    this.movement,
  });

  final String storeId;
  final String eventId;
  final String entityType;
  final String entityId;
  final String operation;
  final int version;
  final CloudInventoryMovement? movement;

  bool get isInventoryMovement => entityType == 'inventoryMovement';

  factory CloudInventoryLedgerChange.fromMap(Map<String, dynamic> map) {
    if (map['storeId'] is! String ||
        map['eventId'] is! String ||
        map['entityType'] is! String ||
        map['entityId'] is! String ||
        map['operation'] is! String ||
        map['version'] is! int ||
        map['payload'] is! Map) {
      throw const FormatException('El cambio remoto del ledger está incompleto.');
    }
    final storeId = map['storeId'] as String;
    final eventId = map['eventId'] as String;
    final entityType = map['entityType'] as String;
    final entityId = map['entityId'] as String;
    final operation = map['operation'] as String;
    final version = map['version'] as int;
    const supportedEntityTypes = <String>{
      'inventoryMovement',
      'purchase',
      'debtMovement',
      'electronicBalanceTransaction',
    };
    if (storeId.trim().isEmpty ||
        storeId.contains('/') ||
        !RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(eventId) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(entityId) ||
        !supportedEntityTypes.contains(entityType) ||
        eventId != entityType + '_' + entityId ||
        version < 1 ||
        operation != 'append') {
      throw const FormatException('La identidad o el tipo del cambio remoto es inválido.');
    }
    if (entityType != 'inventoryMovement') {
      return CloudInventoryLedgerChange(
        storeId: storeId,
        eventId: eventId,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        version: version,
      );
    }
    final payload = Map<String, dynamic>.from(map['payload'] as Map);
    const expectedKeys = <String>{
      'id', 'productId', 'quantityDelta', 'reason', 'createdAt',
    };
    if (payload.length != expectedKeys.length ||
        !payload.keys.toSet().containsAll(expectedKeys) ||
        payload['id'] is! String ||
        payload['productId'] is! String ||
        payload['quantityDelta'] is! int ||
        payload['reason'] is! String ||
        payload['createdAt'] is! String) {
      throw const FormatException('El contenido del movimiento remoto es inválido.');
    }
    final occurredAt = DateTime.tryParse(payload['createdAt'] as String);
    if (occurredAt == null) {
      throw const FormatException('La fecha del movimiento remoto es inválida.');
    }
    final movement = CloudInventoryMovement(
      movementId: payload['id'] as String,
      storeId: storeId,
      productId: payload['productId'] as String,
      delta: payload['quantityDelta'] as int,
      reason: payload['reason'] as String,
      occurredAt: occurredAt,
      // The server cursor orders ledger entries; localVersion is device-local.
      localVersion: 1,
    );
    if (movement.movementId != entityId ||
        eventId != 'inventoryMovement_$entityId') {
      throw const FormatException('La identidad del movimiento remoto no coincide.');
    }
    final invalid = movement.validate(activeStoreId: storeId);
    if (invalid != null) {
      throw FormatException('Movimiento remoto inválido: $invalid.');
    }
    return CloudInventoryLedgerChange(
      storeId: storeId,
      eventId: eventId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      version: version,
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

/// The applier must durably deduplicate eventId before returning.
abstract interface class CloudInventoryLedgerChangeApplier {
  Future<void> apply(CloudInventoryLedgerChange change);
}

/// Validates each page before applying it and advances the durable cursor only
/// after all relevant inventory movements were applied successfully.
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
    if (storeId.trim().isEmpty ||
        storeId.contains('/') ||
        deviceId.trim().isEmpty ||
        deviceId.contains('/')) {
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
        page.changes.length > limit ||
        page.hasMore != (page.changes.length == limit)) {
      throw const FormatException(
        'La página del ledger no coincide con el cursor o el límite solicitado.',
      );
    }
    var expectedVersion = current.version;
    for (final change in page.changes) {
      if (change.storeId != storeId || change.version != expectedVersion + 1) {
        throw const FormatException('El ledger remoto tiene versiones faltantes o de otra tienda.');
      }
      expectedVersion = change.version;
    }
    final expectedCursor =
        page.changes.isEmpty ? current.version : page.changes.last.version;
    if (page.nextCursor != expectedCursor) {
      throw const FormatException('El cursor del ledger no coincide con el último movimiento.');
    }
    for (final change in page.changes) {
      if (change.isInventoryMovement) await _applier.apply(change);
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
).hasMatch(eventId) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,120}
      return CloudInventoryLedgerChange(
        storeId: storeId,
        eventId: eventId,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        version: version,
      );
    }

    final payload = Map<String, dynamic>.from(map['payload'] as Map);
    const expectedKeys = <String>{
      'id', 'productId', 'quantityDelta', 'reason', 'createdAt',
    };
    if (payload.length != expectedKeys.length ||
        !payload.keys.toSet().containsAll(expectedKeys) ||
        payload['id'] is! String ||
        payload['productId'] is! String ||
        payload['quantityDelta'] is! int ||
        payload['reason'] is! String ||
        payload['createdAt'] is! String) {
      throw const FormatException('El contenido del movimiento remoto es inválido.');
    }
    final occurredAt = DateTime.tryParse(payload['createdAt'] as String);
    if (occurredAt == null) {
      throw const FormatException('La fecha del movimiento remoto es inválida.');
    }
    final movement = CloudInventoryMovement(
      movementId: payload['id'] as String,
      storeId: storeId,
      productId: payload['productId'] as String,
      delta: payload['quantityDelta'] as int,
      reason: payload['reason'] as String,
      occurredAt: occurredAt,
      // The server cursor orders ledger entries; localVersion is device-local.
      localVersion: 1,
    );
    if (movement.movementId != entityId ||
        eventId != 'inventoryMovement_$entityId') {
      throw const FormatException('La identidad del movimiento remoto no coincide.');
    }
    final invalid = movement.validate(activeStoreId: storeId);
    if (invalid != null) {
      throw FormatException('Movimiento remoto inválido: $invalid.');
    }
    return CloudInventoryLedgerChange(
      storeId: storeId,
      eventId: eventId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      version: version,
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

/// The applier must durably deduplicate eventId before returning.
abstract interface class CloudInventoryLedgerChangeApplier {
  Future<void> apply(CloudInventoryLedgerChange change);
}

/// Validates each page before applying it and advances the durable cursor only
/// after all relevant inventory movements were applied successfully.
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
    if (storeId.trim().isEmpty ||
        storeId.contains('/') ||
        deviceId.trim().isEmpty ||
        deviceId.contains('/')) {
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
        page.changes.length > limit ||
        page.hasMore != (page.changes.length == limit)) {
      throw const FormatException(
        'La página del ledger no coincide con el cursor o el límite solicitado.',
      );
    }
    var expectedVersion = current.version;
    for (final change in page.changes) {
      if (change.storeId != storeId || change.version != expectedVersion + 1) {
        throw const FormatException('El ledger remoto tiene versiones faltantes o de otra tienda.');
      }
      expectedVersion = change.version;
    }
    final expectedCursor =
        page.changes.isEmpty ? current.version : page.changes.last.version;
    if (page.nextCursor != expectedCursor) {
      throw const FormatException('El cursor del ledger no coincide con el último movimiento.');
    }
    for (final change in page.changes) {
      if (change.isInventoryMovement) await _applier.apply(change);
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
).hasMatch(entityId) ||
        !supportedEntityTypes.contains(entityType) ||
        eventId != '${entityType}_${entityId}' ||
        version < 1 ||
        operation != 'append') {
      throw const FormatException('La identidad o el tipo del cambio remoto es inválido.');
    }
    if (entityType != 'inventoryMovement') {
      return CloudInventoryLedgerChange(
        storeId: storeId,
        eventId: eventId,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        version: version,
      );
    }

    final payload = Map<String, dynamic>.from(map['payload'] as Map);
    const expectedKeys = <String>{
      'id', 'productId', 'quantityDelta', 'reason', 'createdAt',
    };
    if (payload.length != expectedKeys.length ||
        !payload.keys.toSet().containsAll(expectedKeys) ||
        payload['id'] is! String ||
        payload['productId'] is! String ||
        payload['quantityDelta'] is! int ||
        payload['reason'] is! String ||
        payload['createdAt'] is! String) {
      throw const FormatException('El contenido del movimiento remoto es inválido.');
    }
    final occurredAt = DateTime.tryParse(payload['createdAt'] as String);
    if (occurredAt == null) {
      throw const FormatException('La fecha del movimiento remoto es inválida.');
    }
    final movement = CloudInventoryMovement(
      movementId: payload['id'] as String,
      storeId: storeId,
      productId: payload['productId'] as String,
      delta: payload['quantityDelta'] as int,
      reason: payload['reason'] as String,
      occurredAt: occurredAt,
      // The server cursor orders ledger entries; localVersion is device-local.
      localVersion: 1,
    );
    if (movement.movementId != entityId ||
        eventId != 'inventoryMovement_$entityId') {
      throw const FormatException('La identidad del movimiento remoto no coincide.');
    }
    final invalid = movement.validate(activeStoreId: storeId);
    if (invalid != null) {
      throw FormatException('Movimiento remoto inválido: $invalid.');
    }
    return CloudInventoryLedgerChange(
      storeId: storeId,
      eventId: eventId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      version: version,
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

/// The applier must durably deduplicate eventId before returning.
abstract interface class CloudInventoryLedgerChangeApplier {
  Future<void> apply(CloudInventoryLedgerChange change);
}

/// Validates each page before applying it and advances the durable cursor only
/// after all relevant inventory movements were applied successfully.
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
    if (storeId.trim().isEmpty ||
        storeId.contains('/') ||
        deviceId.trim().isEmpty ||
        deviceId.contains('/')) {
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
        page.changes.length > limit ||
        page.hasMore != (page.changes.length == limit)) {
      throw const FormatException(
        'La página del ledger no coincide con el cursor o el límite solicitado.',
      );
    }
    var expectedVersion = current.version;
    for (final change in page.changes) {
      if (change.storeId != storeId || change.version != expectedVersion + 1) {
        throw const FormatException('El ledger remoto tiene versiones faltantes o de otra tienda.');
      }
      expectedVersion = change.version;
    }
    final expectedCursor =
        page.changes.isEmpty ? current.version : page.changes.last.version;
    if (page.nextCursor != expectedCursor) {
      throw const FormatException('El cursor del ledger no coincide con el último movimiento.');
    }
    for (final change in page.changes) {
      if (change.isInventoryMovement) await _applier.apply(change);
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
