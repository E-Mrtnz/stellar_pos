import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_inventory_ledger_inbox.dart';
import 'package:stellar_pos/core/cloud_inventory_ledger_pull.dart';

class _MemoryInboxStorage implements CloudInventoryLedgerInboxStorage {
  final Map<String, Object> data = <String, Object>{};
  int flushCount = 0;
  bool failNextFlush = false;
  @override
  Object? get(String eventId) => data[eventId];
  @override
  Iterable<Object?> get values => data.values;
  @override
  Future<void> put(String eventId, Map<String, Object?> value) async {
    data[eventId] = Map<String, Object?>.from(value);
  }
  @override
  Future<void> flush() async {
    flushCount++;
    if (failNextFlush) {
      failNextFlush = false;
      throw StateError('simulated flush failure');
    }
  }
}

CloudInventoryLedgerChange _movementChange({
  int version = 1,
  String eventId = 'inventoryMovement_move-1',
  String movementId = 'move-1',
  int delta = -3,
  String storeId = 'store-a',
}) => CloudInventoryLedgerChange.fromMap(<String, dynamic>{
  'storeId': storeId,
  'eventId': eventId,
  'entityType': 'inventoryMovement',
  'entityId': movementId,
  'operation': 'append',
  'version': version,
  'payload': <String, Object?>{
    'id': movementId,
    'productId': 'product-1',
    'quantityDelta': delta,
    'reason': 'sale',
    'createdAt': '2026-10-20T12:00:00.000Z',
  },
});

void main() {
  test('persists a movement before acknowledging inbox application', () async {
    final storage = _MemoryInboxStorage();
    final inbox = CloudInventoryLedgerInbox(storage: storage);
    await inbox.apply(_movementChange());
    expect(storage.data.keys, <String>['store-a::inventoryMovement_move-1']);
    expect(storage.flushCount, 1);
    expect((storage.data.values.single as Map)['version'], 1);
  });

  test('replaying identical movement is idempotent', () async {
    final storage = _MemoryInboxStorage();
    final inbox = CloudInventoryLedgerInbox(storage: storage);
    final change = _movementChange();
    await inbox.apply(change);
    await inbox.apply(change);
    expect(storage.data.length, 1);
    expect(storage.flushCount, 2);
  });

  test('retry flushes an already-written inbox record after failure', () async {
    final storage = _MemoryInboxStorage()..failNextFlush = true;
    final inbox = CloudInventoryLedgerInbox(storage: storage);
    final change = _movementChange();

    await expectLater(inbox.apply(change), throwsA(isA<StateError>()));
    expect(storage.data.length, 1);
    expect(storage.flushCount, 1);

    await inbox.apply(change);
    expect(storage.data.length, 1);
    expect(storage.flushCount, 2);
  });

  test('lists pending movements only for the requested store in ledger order', () async {
    final storage = _MemoryInboxStorage();
    final inbox = CloudInventoryLedgerInbox(storage: storage);

    await inbox.apply(_movementChange(
      version: 2,
      eventId: 'inventoryMovement_move-2',
      movementId: 'move-2',
    ));
    await inbox.apply(_movementChange(
      version: 1,
      eventId: 'inventoryMovement_move-1',
      movementId: 'move-1',
    ));
    await inbox.apply(_movementChange(
      storeId: 'store-b',
      version: 1,
      eventId: 'inventoryMovement_move-1',
      movementId: 'move-1',
    ));

    final pending = await inbox.pendingForStore('store-a');
    expect(pending.map((entry) => entry.entityId), <String>['move-1', 'move-2']);
    expect(pending.map((entry) => entry.version), <int>[1, 2]);
    expect(pending.every((entry) => entry.storeId == 'store-a'), isTrue);
    expect((await inbox.pendingForStore('store-b')), hasLength(1));
  });

  test('isolates identical event IDs across different stores', () async {
    final storage = _MemoryInboxStorage();
    final inbox = CloudInventoryLedgerInbox(storage: storage);

    await inbox.apply(_movementChange(storeId: 'store-a'));
    await inbox.apply(_movementChange(storeId: 'store-b'));

    expect(storage.data.keys, containsAll(<String>[
      'store-a::inventoryMovement_move-1',
      'store-b::inventoryMovement_move-1',
    ]));
    expect(storage.data.length, 2);
    expect(storage.flushCount, 2);
  });

  test('rejects event ID reuse with different content', () async {
    final storage = _MemoryInboxStorage();
    final inbox = CloudInventoryLedgerInbox(storage: storage);
    await inbox.apply(_movementChange());
    await expectLater(
      inbox.apply(_movementChange(delta: -4)),
      throwsA(isA<StateError>()),
    );
    expect(storage.data.length, 1);
    expect(storage.flushCount, 1);
  });
}
