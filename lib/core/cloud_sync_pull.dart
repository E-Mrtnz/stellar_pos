import 'package:cloud_functions/cloud_functions.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

class CloudSyncSyntheticChange {
  const CloudSyncSyntheticChange({
    required this.storeId,
    required this.eventId,
    required this.entityId,
    required this.version,
    required this.payload,
    this.entityType = 'syntheticTestValue',
    this.operation = 'set',
    this.localVersion = 1,
  });

  final String storeId;
  final String eventId;
  final String entityId;
  final String entityType;
  final String operation;
  final int localVersion;
  final int version;
  final Map<String, Object?> payload;

  factory CloudSyncSyntheticChange.fromMap(Map<String, dynamic> map) {
    if (map['storeId'] is! String ||
        map['eventId'] is! String ||
        map['entityId'] is! String ||
        map['entityType'] is! String ||
        map['operation'] is! String ||
        map['localVersion'] is! int ||
        map['version'] is! int ||
        map['payload'] is! Map) {
      throw const FormatException('El cambio remoto contiene campos inválidos.');
    }
    return CloudSyncSyntheticChange(
      storeId: map['storeId'] as String,
      eventId: map['eventId'] as String,
      entityId: map['entityId'] as String,
      entityType: map['entityType'] as String,
      operation: map['operation'] as String,
      localVersion: map['localVersion'] as int,
      version: map['version'] as int,
      payload: Map<String, Object?>.from(map['payload'] as Map),
    );
  }
}

class CloudSyncSyntheticPullPage {
  const CloudSyncSyntheticPullPage({
    required this.storeId,
    required this.afterVersion,
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  final String storeId;
  final int afterVersion;
  final List<CloudSyncSyntheticChange> changes;
  final int nextCursor;
  final bool hasMore;
}

abstract interface class CloudSyncSyntheticPullTransport {
  Future<CloudSyncSyntheticPullPage> fetchPage({
    required String storeId,
    required int afterVersion,
    required int limit,
  });
}

class CloudFunctionsSyntheticPullTransport
    implements CloudSyncSyntheticPullTransport {
  CloudFunctionsSyntheticPullTransport({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<CloudSyncSyntheticPullPage> fetchPage({
    required String storeId,
    required int afterVersion,
    required int limit,
  }) async {
    final response = await _functions
        .httpsCallable('pullSyntheticSyncChanges')
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
      throw const FormatException('La página remota de sincronización es inválida.');
    }
    return CloudSyncSyntheticPullPage(
      storeId: data['storeId'] as String,
      afterVersion: data['afterVersion'] as int,
      nextCursor: data['nextCursor'] as int,
      hasMore: data['hasMore'] as bool,
      changes: (data['changes'] as List)
          .map((item) => CloudSyncSyntheticChange.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
    );
  }
}

abstract interface class CloudSyncSyntheticChangeApplier {
  /// Must be idempotent by eventId because a crash can replay a page before its
  /// cursor is committed.
  Future<void> apply(CloudSyncSyntheticChange change);
}

class CloudSyncPullCoordinator {
  CloudSyncPullCoordinator({
    required CloudSyncSyntheticPullTransport transport,
    required CloudSyncSyntheticChangeApplier applier,
    required CloudSyncCursorStore cursors,
  })  : _transport = transport,
        _applier = applier,
        _cursors = cursors;

  final CloudSyncSyntheticPullTransport _transport;
  final CloudSyncSyntheticChangeApplier _applier;
  final CloudSyncCursorStore _cursors;

  Future<CloudSyncSyntheticPullPage> pullOnce({
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
      throw const FormatException('La página remota no coincide con el cursor solicitado.');
    }

    var expectedVersion = current.version;
    for (final change in page.changes) {
      if (change.storeId != storeId ||
          change.entityType != 'syntheticTestValue' ||
          change.operation != 'set' ||
          change.payload.length != 1 ||
          change.payload['value'] is! String ||
          change.version <= expectedVersion ||
          change.localVersion < 1) {
        throw const FormatException('El cambio remoto incumple el contrato sintético.');
      }
      expectedVersion = change.version;
    }
    final expectedCursor = page.changes.isEmpty
        ? current.version
        : page.changes.last.version;
    if (page.nextCursor != expectedCursor) {
      throw const FormatException('El cursor remoto no coincide con el último cambio.');
    }

    // Apply the complete page before committing the cursor. If any apply fails,
    // the same page is replayed next time and the applier must deduplicate.
    for (final change in page.changes) {
      await _applier.apply(change);
    }
    if (page.nextCursor > current.version) {
      final advanced = await _cursors.advance(
        storeId: storeId,
        deviceId: deviceId,
        candidate: CloudSyncCursor(
          storeId: storeId,
          version: page.nextCursor,
        ),
      );
      if (!advanced) {
        throw StateError('No se pudo avanzar el cursor de sincronización.');
      }
    }
    return page;
  }
}
