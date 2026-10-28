import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:stellar_pos/core/cloud_mutation_journal.dart';
import 'package:stellar_pos/core/cloud_sync_outbox.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

class _HiveStorage implements CloudSyncOutboxStorage, CloudMutationJournalStorage {
  _HiveStorage(this.box);

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
  const journalBoxName = 'mutation_journal_restart_test';
  const outboxBoxName = 'mutation_outbox_restart_test';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stellar_journal_restart_');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('replays an interrupted durable mutation after Hive boxes reopen', () async {
    final journalBox = await Hive.openBox<dynamic>(journalBoxName);
    final outboxBox = await Hive.openBox<dynamic>(outboxBoxName);
    var outbox = CloudSyncOutbox(
      storage: _HiveStorage(outboxBox),
    );
    var journal = CloudMutationJournal(
      outbox: outbox,
      storage: _HiveStorage(journalBox),
    );

    final localRecords = <String, Object?>{};
    var failOnce = true;
    final entry = CloudMutationJournalEntry(
      mutationId: 'mutation-restart-1',
      storeId: 'store-a',
      entityType: 'product',
      entityId: 'product-7',
      operation: CloudSyncOperation.update,
      localVersion: 7,
      createdAt: DateTime.utc(2026, 10, 20, 12),
      localMutation: const <String, Object?>{
        'productId': 'product-7',
        'name': 'Milk',
      },
      eventPayload: const <String, Object?>{
        'productId': 'product-7',
        'name': 'Milk',
      },
    );

    await expectLater(
      journal.commit(
        entry: entry,
        applyLocal: (mutation) async {
          localRecords.putIfAbsent(
            mutation['productId'] as String,
            () => mutation['name'],
          );
          if (failOnce) {
            failOnce = false;
            throw StateError('simulated interruption after local apply');
          }
        },
      ),
      throwsStateError,
    );
    expect(localRecords['product-7'], 'Milk');
    expect(await outbox.pendingForStore('store-a'), isEmpty);

    await Hive.close();
    Hive.init(directory.path);

    final reopenedJournalBox = await Hive.openBox<dynamic>(journalBoxName);
    final reopenedOutboxBox = await Hive.openBox<dynamic>(outboxBoxName);
    outbox = CloudSyncOutbox(storage: _HiveStorage(reopenedOutboxBox));
    journal = CloudMutationJournal(
      outbox: outbox,
      storage: _HiveStorage(reopenedJournalBox),
    );

    final recovered = await journal.recover(
      storeId: 'store-a',
      applyLocal: (mutation) async {
        localRecords.putIfAbsent(
          mutation['productId'] as String,
          () => mutation['name'],
        );
      },
    );

    expect(recovered, 1);
    expect(localRecords, <String, Object?>{'product-7': 'Milk'});
    final pending = await outbox.pendingForStore('store-a');
    expect(pending, hasLength(1));
    expect(pending.single.eventId, 'mutation-restart-1');
    expect(pending.single.entityId, 'product-7');
    expect(
      (reopenedJournalBox.get('mutation-restart-1') as Map)['status'],
      'completed',
    );
  });
}
