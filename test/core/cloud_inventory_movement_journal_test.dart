import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_inventory_movement.dart';
import 'package:stellar_pos/core/cloud_mutation_journal.dart';
import 'package:stellar_pos/core/cloud_sync_outbox.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

class _MemoryStorage
    implements CloudSyncOutboxStorage, CloudMutationJournalStorage {
  final Map<String, Object> data = <String, Object>{};

  @override
  Object? get(String key) => data[key];

  @override
  Iterable<Object?> get values => data.values;

  @override
  Future<void> put(String key, Object value) async {
    data[key] = value;
  }

  @override
  Future<void> flush() async {}
}

CloudInventoryMovement _movement() => CloudInventoryMovement(
  movementId: 'movement-001',
  storeId: 'store-a',
  productId: 'product-123',
  delta: -3,
  reason: 'sale',
  occurredAt: DateTime.utc(2026, 10, 20, 12),
  localVersion: 7,
);

void main() {
  test('journal persists a movement intent before enqueueing its stable event',
      () async {
    final outboxStorage = _MemoryStorage();
    final journalStorage = _MemoryStorage();
    final outbox = CloudSyncOutbox(storage: outboxStorage);
    final journal = CloudMutationJournal(
      outbox: outbox,
      storage: journalStorage,
    );
    final movement = _movement();
    final event = movement.toSyncEvent();
    var localApplyCalls = 0;

    await journal.commit(
      entry: CloudMutationJournalEntry(
        mutationId: event.eventId,
        storeId: movement.storeId,
        entityType: event.entityType,
        entityId: event.entityId,
        operation: event.operation,
        localVersion: movement.localVersion,
        createdAt: movement.occurredAt,
        localMutation: <String, Object?>{
          'kind': 'inventoryMovement',
          'payload': movement.toPayload(),
        },
        eventPayload: event.payload,
      ),
      applyLocal: (mutation) async {
        localApplyCalls++;
        expect(mutation['kind'], 'inventoryMovement');
        expect(mutation['payload'], movement.toPayload());
      },
    );

    final pending = await outbox.pendingForStore('store-a');
    expect(pending, hasLength(1));
    expect(pending.single.eventId, 'inventory-movement:movement-001');
    expect(pending.single.entityType, 'inventoryMovement');
    expect(pending.single.entityId, 'movement-001');
    expect(pending.single.payload, movement.toPayload());
    expect(localApplyCalls, 1);
    expect(
      (journalStorage.data[event.eventId] as Map)['status'],
      CloudMutationJournalStatus.completed.name,
    );
  });

  test('recovery queues a movement event without repeating an applied mutation',
      () async {
    final outboxStorage = _MemoryStorage();
    final journalStorage = _MemoryStorage();
    final outbox = CloudSyncOutbox(storage: outboxStorage);
    final journal = CloudMutationJournal(
      outbox: outbox,
      storage: journalStorage,
    );
    final movement = _movement();
    final event = movement.toSyncEvent();
    var applyCalls = 0;

    // Simulate a crash after the journal durably records localApplied.
    journalStorage.data[event.eventId] = <String, Object?>{
      ...CloudMutationJournalEntry(
        mutationId: event.eventId,
        storeId: movement.storeId,
        entityType: event.entityType,
        entityId: event.entityId,
        operation: CloudSyncOperation.create,
        localVersion: movement.localVersion,
        createdAt: movement.occurredAt,
        localMutation: <String, Object?>{
          'kind': 'inventoryMovement',
          'payload': movement.toPayload(),
        },
        eventPayload: event.payload,
        status: CloudMutationJournalStatus.localApplied,
      ).toMap(),
    };

    final recovered = await journal.recover(
      storeId: movement.storeId,
      applyLocal: (_) async => applyCalls++,
    );

    expect(recovered, 1);
    expect(applyCalls, 0);
    expect(await outbox.pendingForStore(movement.storeId), hasLength(1));
    expect(
      (journalStorage.data[event.eventId] as Map)['status'],
      CloudMutationJournalStatus.completed.name,
    );
  });

  test('movement IDs cannot be reused with a different event payload', () async {
    final storage = _MemoryStorage();
    final outbox = CloudSyncOutbox(storage: storage);
    final original = _movement().toSyncEvent();
    await outbox.enqueue(original);

    final conflicting = CloudSyncEvent(
      eventId: original.eventId,
      storeId: original.storeId,
      entityType: original.entityType,
      entityId: original.entityId,
      operation: original.operation,
      localVersion: original.localVersion,
      createdAt: original.createdAt,
      payload: <String, Object?>{
        ...original.payload,
        'delta': 99,
      },
    );

    await expectLater(outbox.enqueue(conflicting), throwsStateError);
    expect(await outbox.pendingForStore('store-a'), hasLength(1));
  });
}
