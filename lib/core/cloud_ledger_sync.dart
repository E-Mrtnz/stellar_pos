import 'package:cloud_functions/cloud_functions.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

/// Immutable business ledgers supported by the trusted cloud receiver.
/// Stock is deliberately represented by signed movements, never by syncing
/// the mutable Product.stock field with last-write-wins.
enum CloudLedgerEntityType {
  inventoryMovement,
  purchase,
  debtMovement,
  electronicBalanceTransaction,
}

class CloudLedgerAcceptance {
  const CloudLedgerAcceptance({
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.duplicate,
  });

  final CloudLedgerEntityType entityType;
  final String entityId;
  final int version;
  final bool duplicate;

  factory CloudLedgerAcceptance.fromResponse(
    Map<String, dynamic> response, {
    required CloudLedgerEntityType expectedType,
    required String expectedId,
  }) {
    final status = response['status'];
    final version = response['version'];
    if (response['entityType'] != expectedType.name ||
        response['entityId'] != expectedId ||
        (status != 'applied' && status != 'duplicate') ||
        version is! int || version < 1) {
      throw const FormatException('Respuesta de ledger remoto inválida.');
    }
    return CloudLedgerAcceptance(
      entityType: expectedType,
      entityId: expectedId,
      version: version,
      duplicate: status == 'duplicate',
    );
  }
}

class CloudLedgerChange {
  const CloudLedgerChange({
    required this.storeId,
    required this.eventId,
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.payload,
  });

  final String storeId;
  final String eventId;
  final CloudLedgerEntityType entityType;
  final String entityId;
  final int version;
  final Map<String, dynamic> payload;

  factory CloudLedgerChange.fromMap(Map<String, dynamic> map) {
    final typeName = map['entityType'];
    final type = CloudLedgerEntityType.values.where((item) => item.name == typeName);
    final payload = map['payload'];
    if (type.isEmpty ||
        map['storeId'] is! String ||
        map['eventId'] is! String ||
        map['entityId'] is! String ||
        map['eventId'] != '${type.isEmpty ? '' : type.first.name}_${map['entityId']}' ||
        map['operation'] != 'append' ||
        map['version'] is! int ||
        (map['version'] as int) < 1 ||
        payload is! Map ||
        payload['id'] != map['entityId']) {
      throw const FormatException('Cambio de ledger remoto inválido.');
    }
    return CloudLedgerChange(
      storeId: map['storeId'] as String,
      eventId: map['eventId'] as String,
      entityType: type.first,
      entityId: map['entityId'] as String,
      version: map['version'] as int,
      payload: Map<String, dynamic>.from(payload),
    );
  }
}

class CloudLedgerPullPage {
  const CloudLedgerPullPage({
    required this.storeId,
    required this.afterVersion,
    required this.nextCursor,
    required this.hasMore,
    required this.changes,
  });

  final String storeId;
  final int afterVersion;
  final int nextCursor;
  final bool hasMore;
  final List<CloudLedgerChange> changes;

  factory CloudLedgerPullPage.fromResponse(
    Map<String, dynamic> response, {
    required String expectedStoreId,
    required int expectedCursor,
  }) {
    final changesRaw = response['changes'];
    final nextCursor = response['nextCursor'];
    final afterVersion = response['afterVersion'];
    if (response['storeId'] != expectedStoreId ||
        afterVersion != expectedCursor ||
        nextCursor is! int ||
        nextCursor < expectedCursor ||
        changesRaw is! List ||
        response['hasMore'] is! bool) {
      throw const FormatException('Página de ledger remota inválida.');
    }
    final changes = changesRaw.map((raw) {
      if (raw is! Map) throw const FormatException('Cambio de ledger inválido.');
      return CloudLedgerChange.fromMap(Map<String, dynamic>.from(raw));
    }).toList(growable: false);
    var previous = expectedCursor;
    for (final change in changes) {
      if (change.storeId != expectedStoreId || change.version <= previous) {
        throw const FormatException('El cursor del ledger no es monotónico.');
      }
      previous = change.version;
    }
    if ((changes.isEmpty && nextCursor != expectedCursor) ||
        (changes.isNotEmpty && nextCursor != changes.last.version)) {
      throw const FormatException('El cursor no coincide con la página recibida.');
    }
    return CloudLedgerPullPage(
      storeId: expectedStoreId,
      afterVersion: expectedCursor,
      nextCursor: nextCursor,
      hasMore: response['hasMore'] as bool,
      changes: changes,
    );
  }
}

abstract interface class CloudLedgerGateway {
  Future<CloudLedgerAcceptance> append({
    required String storeId,
    required CloudLedgerEntityType entityType,
    required String entityId,
    required Map<String, dynamic> entry,
  });

  Future<CloudLedgerPullPage> pull({
    required String storeId,
    required int afterVersion,
    int limit = 50,
  });
}

/// Callable adapter only. It does not mutate local repositories, project stock,
/// or advance a durable cursor; those steps must be coordinated by a caller.
class CloudFunctionsLedgerGateway implements CloudLedgerGateway {
  CloudFunctionsLedgerGateway({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<CloudLedgerAcceptance> append({
    required String storeId,
    required CloudLedgerEntityType entityType,
    required String entityId,
    required Map<String, dynamic> entry,
  }) async {
    _validateIdentity(storeId, entityId);
    if (entry['id'] != entityId) {
      throw ArgumentError('El ID de la entrada debe coincidir con entityId.');
    }
    final response = await _functions.httpsCallable('acceptCloudLedgerEntry').call(
      <String, Object?>{
        'storeId': storeId,
        'entityType': entityType.name,
        'entityId': entityId,
        'entry': entry,
      },
    );
    return CloudLedgerAcceptance.fromResponse(
      Map<String, dynamic>.from(response.data as Map),
      expectedType: entityType,
      expectedId: entityId,
    );
  }

  @override
  Future<CloudLedgerPullPage> pull({
    required String storeId,
    required int afterVersion,
    int limit = 50,
  }) async {
    _validateIdentity(storeId, 'cursor');
    if (afterVersion < 0 || limit < 1 || limit > 100) {
      throw ArgumentError('Cursor o límite de página inválido.');
    }
    final response = await _functions.httpsCallable('pullCloudLedgerChanges').call(
      <String, Object?>{
        'storeId': storeId,
        'afterVersion': afterVersion,
        'limit': limit,
      },
    );
    return CloudLedgerPullPage.fromResponse(
      Map<String, dynamic>.from(response.data as Map),
      expectedStoreId: storeId,
      expectedCursor: afterVersion,
    );
  }

  void _validateIdentity(String storeId, String entityId) {
    final validId = RegExp(r'^[A-Za-z0-9_-]{1,120}$');
    if (!validId.hasMatch(storeId) || !validId.hasMatch(entityId)) {
      throw ArgumentError('Los identificadores de tienda y ledger no son válidos.');
    }
  }
}


abstract interface class CloudLedgerRemoteApplier {
  /// Must append/project by stable eventId without generating another outbox
  /// event. A failed page may replay before its cursor is committed.
  Future<void> apply(CloudLedgerChange change);
}

/// Applies a complete ledger page before persisting the durable cursor.
class CloudLedgerPullCoordinator {
  CloudLedgerPullCoordinator({
    required CloudLedgerGateway gateway,
    required CloudLedgerRemoteApplier applier,
    required CloudSyncCursorStore cursors,
  }) : _gateway = gateway, _applier = applier, _cursors = cursors;

  final CloudLedgerGateway _gateway;
  final CloudLedgerRemoteApplier _applier;
  final CloudSyncCursorStore _cursors;

  // Serialize pulls for each store/device pair. Without this guard, two callers
  // can read the same cursor, apply the same page concurrently, and race to
  // advance it. Different stores/devices remain independent.
  final Map<String, Future<void>> _pullLocks = <String, Future<void>>{};

  Future<T> _runExclusive<T>(
    String key,
    Future<T> Function() action,
  ) async {
    final previous = _pullLocks[key] ?? Future<void>.value();
    final release = Completer<void>();
    final tail = release.future;
    _pullLocks[key] = tail;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
      if (identical(_pullLocks[key], tail)) _pullLocks.remove(key);
    }
  }

  Future<CloudLedgerPullPage> pullOnce({
    required String storeId,
    required String deviceId,
    int limit = 50,
  }) {
    if (storeId.trim().isEmpty || storeId.contains('/') ||
        deviceId.trim().isEmpty || deviceId.contains('/')) {
      throw ArgumentError('storeId y deviceId deben ser identificadores válidos.');
    }
    final key = '$deviceId::$storeId';
    return _runExclusive(
      key,
      () => _pullOnce(storeId: storeId, deviceId: deviceId, limit: limit),
    );
  }

  Future<CloudLedgerPullPage> _pullOnce({
    required String storeId,
    required String deviceId,
    required int limit,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'El límite debe estar entre 1 y 100.');
    }
    final current = await _cursors.read(storeId: storeId, deviceId: deviceId) ??
        CloudSyncCursor(storeId: storeId, version: 0);
    final page = await _gateway.pull(
      storeId: storeId,
      afterVersion: current.version,
      limit: limit,
    );
    if (page.storeId != storeId || page.afterVersion != current.version ||
        page.changes.length > limit) {
      throw const FormatException('La página de ledger no corresponde al cursor actual.');
    }
    var expectedVersion = current.version;
    for (final change in page.changes) {
      if (change.storeId != storeId || change.version != expectedVersion + 1) {
        throw const FormatException('La secuencia del ledger contiene un salto o una tienda distinta.');
      }
      expectedVersion = change.version;
    }
    if (page.nextCursor != expectedVersion ||
        (page.hasMore && page.changes.length != limit)) {
      throw const FormatException('El cursor o la paginación del ledger son inconsistentes.');
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
      if (!advanced) throw StateError('No se pudo avanzar el cursor del ledger.');
    }
    return page;
  }
}
