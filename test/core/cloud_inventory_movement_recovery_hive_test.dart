import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:stellar_pos/core/cloud_inventory_movement.dart';
import 'package:stellar_pos/core/cloud_mutation_journal.dart';
import 'package:stellar_pos/core/cloud_sync_outbox.dart';

class _HiveMovementStorage
    implements CloudSyncOutboxStorage, CloudMutationJournalStorage {
  _HiveMovementStorage(this.box);

  final Box<dynamic> box;

  @override
  Object? get(String key) => box.get(key);

  @override
  Iterable<Object?> get values => box.values;

  @override
  Future<void> put(String key, Object value) => box.put(key, value);

  @override
  Future<void> flush() => box.flush();
}

void main() {
  late Directory directory;
  const journalBoxName = 'inventory_movement_journal_restart';
  const outboxBoxName = 'inventory_movement_outbox_restart';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stellar_inventory_restart_');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('movement is recovered after Hive restart without applying stock twice',
      () async {
    var journalBox = await Hive.openBox<dynamic>(journalBoxName);
    var outboxBox = await Hive.openBox<dynamic>(outboxBoxName);
    var outbox = CloudSyncOutbox(storage: _HiveMovementStorage(outboxBox));
    var journal = CloudMutationJournal(
      outbox: outbox,
      storage: _HiveMovementStorage(journalBox),
    );
    final movement = CloudInventoryMovement(
      movementId: 'movement-restart-1',
      storeId: 'store-a',
      productId: 'product-7',
      delta: -2,
      reason: 'sale',
      occurredAt: DateTime.utc(2026, 10, 20, 12),
      localVersion: 8,
    );
    final event = movement.toSyncEvent();
    final localMovements = <String, Map<String, Object?>>{};
    var failOnce = true;

    await expectLater(
      journal.commit(
        entry: CloudMutationJournalEntry(
          mutationId: event.eventId,
          storeId: movement.storeId,
          entityType: event.entityType,
          entityId: event.entityId,
          operation: event.operation,
          localVersion: event.localVersion,
          createdAt: event.createdAt,
          localMutation: <String, Object?>{
            'movementId': movement.movementId,
            'productId': movement.productId,
            'delta': movement.delta,
          },
          eventPayload: event.payload,
        ),
        applyLocal: (mutation) async {
          localMovements.putIfAbsent(
            mutation['movementId'] as String,
            () => Map<String, Object?>.from(mutation),
          );
          if (failOnce) {
            failOnce = false;
            throw StateError('simulated process interruption');
          }
        },
      ),
      throwsStateError,
    );

    expect(localMovements, hasLength(1));
    expect(await outbox.pendingForStore(movement.storeId), isEmpty);
    expect(
      (journalBox.get(event.eventId) as Map)['status'],
      CloudMutationJournalStatus.prepared.name,
    );

    await Hive.close();
    Hive.init(directory.path);
    journalBox = await Hive.openBox<dynamic>(journalBoxName);
    outboxBox = await Hive.openBox<dynamic>(outboxBoxName);
    outbox = CloudSyncOutbox(storage: _HiveMovementStorage(outboxBox));
    journal = CloudMutationJournal(
      outbox: outbox,
      storage: _HiveMovementStorage(journalBox),
    );

    final recovered = await journal.recover(
      storeId: movement.storeId,
      applyLocal: (mutation) async {
        localMovements.putIfAbsent(
          mutation['movementId'] as String,
          () => Map<String, Object?>.from(mutation),
        );
      },
    );

    expect(recovered, 1);
    expect(localMovements, hasLength(1));
    expect(localMovements[movement.movementId]?['delta'], -2);
    final pending = await outbox.pendingForStore(movement.storeId);
    expect(pending, hasLength(1));
    expect(pending.single.eventId, 'inventory-movement:movement-restart-1');
    expect(pending.single.payload, movement.toPayload());
    expect(
      (journalBox.get(event.eventId) as Map)['status'],
      CloudMutationJournalStatus.completed.name,
    );
  });
}
