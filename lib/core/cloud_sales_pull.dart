import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/data/repositories/sale_repository.dart';

class CloudSaleChange {
  const CloudSaleChange({
    required this.storeId,
    required this.eventId,
    required this.saleId,
    required this.version,
    required this.localVersion,
    required this.sale,
    this.entityType = 'sale',
    this.operation = 'set',
  });

  final String storeId;
  final String eventId;
  final String saleId;
  final int version;
  final int localVersion;
  final String entityType;
  final String operation;
  final SaleRecord sale;

  factory CloudSaleChange.fromMap(Map<String, dynamic> map) {
    if (map['storeId'] is! String ||
        map['eventId'] is! String ||
        map['entityId'] is! String ||
        map['entityType'] is! String ||
        map['operation'] is! String ||
        map['localVersion'] is! int ||
        map['version'] is! int ||
        map['payload'] is! Map) {
      throw const FormatException('El cambio remoto de venta contiene campos inválidos.');
    }
    final saleMap = Map<String, dynamic>.from(map['payload'] as Map);
    final sale = SaleRecord.fromMap(saleMap);
    if (sale.id != map['entityId'] || sale.id != map['eventId']) {
      throw const FormatException('La identidad de la venta remota no coincide.');
    }
    return CloudSaleChange(
      storeId: map['storeId'] as String,
      eventId: map['eventId'] as String,
      saleId: map['entityId'] as String,
      entityType: map['entityType'] as String,
      operation: map['operation'] as String,
      localVersion: map['localVersion'] as int,
      version: map['version'] as int,
      sale: sale,
    );
  }
}

class CloudSalesPullPage {
  const CloudSalesPullPage({
    required this.storeId,
    required this.afterVersion,
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });
  final String storeId;
  final int afterVersion;
  final List<CloudSaleChange> changes;
  final int nextCursor;
  final bool hasMore;
}

abstract interface class CloudSalesPullTransport {
  Future<CloudSalesPullPage> fetchPage({
    required String storeId,
    required int afterVersion,
    required int limit,
  });
}

class CloudFunctionsSalesPullTransport implements CloudSalesPullTransport {
  CloudFunctionsSalesPullTransport({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;
  final FirebaseFunctions _functions;

  @override
  Future<CloudSalesPullPage> fetchPage({
    required String storeId,
    required int afterVersion,
    required int limit,
  }) async {
    final response = await _functions.httpsCallable('pullCloudSales').call(
      <String, Object?>{
        'storeId': storeId,
        'afterVersion': afterVersion,
        'limit': limit,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['storeId'] is! String ||
        data['afterVersion'] is! int ||
        data['nextCursor'] is! int ||
        data['hasMore'] is! bool ||
        data['changes'] is! List) {
      throw const FormatException('La página de ventas remotas es inválida.');
    }
    return CloudSalesPullPage(
      storeId: data['storeId'] as String,
      afterVersion: data['afterVersion'] as int,
      nextCursor: data['nextCursor'] as int,
      hasMore: data['hasMore'] as bool,
      changes: (data['changes'] as List)
          .map((value) => CloudSaleChange.fromMap(Map<String, dynamic>.from(value as Map)))
          .toList(growable: false),
    );
  }
}

abstract interface class CloudSaleRemoteApplier {
  /// Must upsert by stable sale ID and must not enqueue another outgoing event.
  /// A page may replay if the app stops before the cursor is persisted.
  Future<void> apply(CloudSaleChange change);
}

class CloudSalesPullCoordinator {
  CloudSalesPullCoordinator({
    required CloudSalesPullTransport transport,
    required CloudSaleRemoteApplier applier,
    required CloudSyncCursorStore cursors,
  }) : _transport = transport, _applier = applier, _cursors = cursors;

  final CloudSalesPullTransport _transport;
  final CloudSaleRemoteApplier _applier;
  final CloudSyncCursorStore _cursors;

  Future<CloudSalesPullPage> pullOnce({
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
      storeId: storeId, afterVersion: current.version, limit: limit,
    );
    if (page.storeId != storeId || page.afterVersion != current.version ||
        page.changes.length > limit || page.nextCursor < current.version) {
      throw const FormatException('La página remota no coincide con el cursor solicitado.');
    }
    var expectedVersion = current.version;
    for (final change in page.changes) {
      if (change.storeId != storeId || change.entityType != 'sale' ||
          change.operation != 'set' || change.eventId != change.saleId ||
          change.sale.id != change.saleId || change.version != expectedVersion + 1 ||
          change.localVersion < 1 || change.sale.saleNumber == null ||
          change.sale.saleNumber!.trim().isEmpty ||
          change.sale.metadata.storeId != storeId) {
        throw const FormatException('El cambio remoto incumple el contrato de ventas.');
      }
      expectedVersion = change.version;
    }
    final expectedCursor = page.changes.isEmpty ? current.version : page.changes.last.version;
    if (page.nextCursor != expectedCursor) {
      throw const FormatException('El cursor no coincide con la última venta recibida.');
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
      if (!advanced) throw StateError('No se pudo avanzar el cursor de ventas.');
    }
    return page;
  }
}


/// Minimal local write contract used by the remote sale applier.
abstract interface class CloudSaleLocalStore {
  Future<SaleRecord?> getById(String id);
  Future<void> save(SaleRecord sale);
}

/// Adapter for the app's local Hive repository. It never emits outgoing sync
/// events; incoming records therefore cannot form an echo loop.
class SaleRepositoryCloudSaleLocalStore implements CloudSaleLocalStore {
  SaleRepositoryCloudSaleLocalStore({SaleRepository? repository})
      : _repository = repository ?? SaleRepository();
  final SaleRepository _repository;

  @override
  Future<SaleRecord?> getById(String id) => _repository.getById(id);

  @override
  Future<void> save(SaleRecord sale) => _repository.save(sale);
}

/// Idempotent local upsert for accepted remote sales. A same-ID record with
/// different business facts is preserved and surfaced as a conflict instead
/// of being silently overwritten.
class SaleRepositoryCloudRemoteApplier implements CloudSaleRemoteApplier {
  SaleRepositoryCloudRemoteApplier({required CloudSaleLocalStore local})
      : _local = local;
  final CloudSaleLocalStore _local;

  @override
  Future<void> apply(CloudSaleChange change) async {
    final incoming = change.sale;
    final existing = await _local.getById(change.saleId);
    if (existing != null && _businessFingerprint(existing) != _businessFingerprint(incoming)) {
      throw StateError('Conflicto: existe una venta local con el mismo ID y distinto contenido.');
    }
    await _local.save(incoming);
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
