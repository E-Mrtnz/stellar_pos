import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_inventory_ledger_pull.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';

class _MemoryCursorStorage implements CloudSyncCursorStorage {
  final Map<String, Object> data = <String, Object>{};
  @override
  Object? get(String key) => data[key];
  @override
  Future<void> put(String key, Object value) async { data[key] = value; }
  @override
  Future<void> flush() async {}
}

class _FakeTransport implements CloudInventoryLedgerPullTransport {
  _FakeTransport(this.page);
  final CloudInventoryLedgerPage page;
  int? requestedCursor;
  @override
  Future<CloudInventoryLedgerPage> fetchPage({
    required String storeId,
    required int afterVersion,
    required int limit,
  }) async {
    requestedCursor = afterVersion;
    return page;
  }
}

class _FakeApplier implements CloudInventoryLedgerChangeApplier {
  final List<String> applied = <String>[];
  int? failAt;
  @override
  Future<void> apply(CloudInventoryLedgerChange change) async {
    applied.add(change.eventId);
    if (failAt == applied.length) throw StateError('simulated apply failure');
  }
}

CloudInventoryLedgerChange _change(int version, String id) =>
    CloudInventoryLedgerChange.fromMap(<String, dynamic>{
      'storeId': 'store-a',
      'eventId': 'inventoryMovement_$id',
      'entityType': 'inventoryMovement',
      'entityId': id,
      'operation': 'append',
      'version': version,
      'payload': <String, Object?>{
        'id': id,
        'productId': 'product-1',
        'quantityDelta': -2,
        'reason': 'sale',
        'createdAt': '2026-10-20T12:00:00.000Z',
      },
    });

void main() {
  test('parses the server ledger schema as an immutable movement', () {
    final change = _change(1, 'movement-1');
    expect(change.movement!.movementId, 'movement-1');
    expect(change.movement!.productId, 'product-1');
    expect(change.movement!.delta, -2);
    expect(change.movement!.storeId, 'store-a');
  });

  test('rejects mismatched identity and unsafe movement data', () {
    expect(
      () => CloudInventoryLedgerChange.fromMap(<String, dynamic>{
        'storeId': 'store-a',
        'eventId': 'inventoryMovement_other',
        'entityType': 'inventoryMovement',
        'entityId': 'movement-1',
        'operation': 'append',
        'version': 1,
        'payload': <String, Object?>{
          'id': 'movement-1',
          'productId': 'product-1',
          'quantityDelta': 0,
          'reason': 'sale',
          'createdAt': '2026-10-20T12:00:00.000Z',
        },
      }),
      throwsFormatException,
    );
  });

  test('applies the page before advancing its durable cursor', () async {
    final cursors = CloudSyncCursorStore(storage: _MemoryCursorStorage());
    final transport = _FakeTransport(CloudInventoryLedgerPage(
      storeId: 'store-a',
      afterVersion: 0,
      changes: <CloudInventoryLedgerChange>[
        _change(1, 'movement-1'),
        _change(2, 'movement-2'),
      ],
      nextCursor: 2,
      hasMore: false,
    ));
    final applier = _FakeApplier();
    final coordinator = CloudInventoryLedgerPullCoordinator(
      transport: transport,
      applier: applier,
      cursors: cursors,
    );
    final page = await coordinator.pullOnce(storeId: 'store-a', deviceId: 'device-a');
    expect(page.nextCursor, 2);
    expect(transport.requestedCursor, 0);
    expect(applier.applied, <String>[
      'inventoryMovement_movement-1',
      'inventoryMovement_movement-2',
    ]);
    expect((await cursors.read(storeId: 'store-a', deviceId: 'device-a'))?.version, 2);
  });

  test('does not advance cursor when applying a movement fails', () async {
    final cursors = CloudSyncCursorStore(storage: _MemoryCursorStorage());
    final transport = _FakeTransport(CloudInventoryLedgerPage(
      storeId: 'store-a',
      afterVersion: 0,
      changes: <CloudInventoryLedgerChange>[_change(1, 'movement-1')],
      nextCursor: 1,
      hasMore: false,
    ));
    final applier = _FakeApplier()..failAt = 1;
    final coordinator = CloudInventoryLedgerPullCoordinator(
      transport: transport,
      applier: applier,
      cursors: cursors,
    );
    await expectLater(
      coordinator.pullOnce(storeId: 'store-a', deviceId: 'device-a'),
      throwsA(isA<StateError>()),
    );
    expect(await cursors.read(storeId: 'store-a', deviceId: 'device-a'), isNull);
  });


  test('advances shared ledger cursor across other immutable entity types', () async {
    final cursors = CloudSyncCursorStore(storage: _MemoryCursorStorage());
    final other = CloudInventoryLedgerChange.fromMap(<String, dynamic>{
      'storeId': 'store-a',
      'eventId': 'purchase_purchase-1',
      'entityType': 'purchase',
      'entityId': 'purchase-1',
      'operation': 'append',
      'version': 1,
      'payload': <String, Object?>{'id': 'purchase-1'},
    });
    final transport = _FakeTransport(CloudInventoryLedgerPage(
      storeId: 'store-a',
      afterVersion: 0,
      changes: <CloudInventoryLedgerChange>[other, _change(2, 'movement-2')],
      nextCursor: 2,
      hasMore: false,
    ));
    final applier = _FakeApplier();
    final coordinator = CloudInventoryLedgerPullCoordinator(
      transport: transport,
      applier: applier,
      cursors: cursors,
    );
    await coordinator.pullOnce(storeId: 'store-a', deviceId: 'device-a');
    expect(applier.applied, <String>['inventoryMovement_movement-2']);
    expect((await cursors.read(storeId: 'store-a', deviceId: 'device-a'))?.version, 2);
  });

  test('rejects gaps in ledger sequence before applying anything', () async {
    final cursors = CloudSyncCursorStore(storage: _MemoryCursorStorage());
    final transport = _FakeTransport(CloudInventoryLedgerPage(
      storeId: 'store-a',
      afterVersion: 0,
      changes: <CloudInventoryLedgerChange>[
        _change(1, 'movement-1'),
        _change(3, 'movement-3'),
      ],
      nextCursor: 3,
      hasMore: false,
    ));
    final applier = _FakeApplier();
    final coordinator = CloudInventoryLedgerPullCoordinator(
      transport: transport,
      applier: applier,
      cursors: cursors,
    );
    await expectLater(
      coordinator.pullOnce(storeId: 'store-a', deviceId: 'device-a'),
      throwsFormatException,
    );
    expect(applier.applied, isEmpty);
    expect(await cursors.read(storeId: 'store-a', deviceId: 'device-a'), isNull);
  });
}
