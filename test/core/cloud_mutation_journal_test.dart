import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_mutation_journal.dart';
import 'package:stellar_pos/core/cloud_sync_outbox.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

class _MemoryStorage implements CloudSyncOutboxStorage, CloudMutationJournalStorage {
  final Map<String, Object> data = <String, Object>{};
  @override Object? get(String key) => data[key];
  @override Iterable<Object?> get values => data.values;
  @override Future<void> put(String key, Object value) async { data[key] = value; }
  @override Future<void> flush() async {}
}

CloudMutationJournalEntry _entry({
  String id = 'mutation-1',
  String store = 'store-a',
  Map<String, Object?> local = const <String, Object?>{'saleId': 'sale-1', 'total': 4},
}) => CloudMutationJournalEntry(
  mutationId: id,
  storeId: store,
  entityType: 'sale',
  entityId: 'sale-1',
  operation: CloudSyncOperation.create,
  localVersion: 1,
  createdAt: DateTime.utc(2026, 10, 16),
  localMutation: local,
  eventPayload: const <String, Object?>{'saleId': 'sale-1', 'total': 4},
);

void main() {
  late _MemoryStorage storage;
  late CloudSyncOutbox outbox;
  late CloudMutationJournal journal;

  setUp(() {
    storage = _MemoryStorage();
    outbox = CloudSyncOutbox(storage: storage);
    journal = CloudMutationJournal(outbox: outbox, storage: storage);
  });

  test('records intent before applying and queues one stable event', () async {
    final local = <String, Object?>{};
    var calls = 0;
    await journal.commit(entry: _entry(), applyLocal: (mutation) async {
      calls++;
      local.putIfAbsent(mutation['saleId'] as String, () => mutation['total']);
    });

    expect(local['sale-1'], 4);
    expect(calls, 1);
    expect((await outbox.pendingForStore('store-a')), hasLength(1));
    final record = Map<String, Object?>.from(storage.data['mutation-1'] as Map);
    expect(record['status'], 'completed');

    await journal.commit(entry: _entry(), applyLocal: (mutation) async {
      calls++;
      local.putIfAbsent(mutation['saleId'] as String, () => mutation['total']);
    });
    expect(calls, 1);
    expect(await outbox.pendingForStore('store-a'), hasLength(1));
  });

  test('replays an interrupted intent and completes the outbox event', () async {
    var failOnce = true;
    final local = <String, Object?>{};
    await expectLater(
      journal.commit(entry: _entry(), applyLocal: (mutation) async {
        local.putIfAbsent(mutation['saleId'] as String, () => mutation['total']);
        if (failOnce) {
          failOnce = false;
          throw StateError('simulated process interruption');
        }
      }),
      throwsStateError,
    );

    expect(local['sale-1'], 4);
    expect(await outbox.pendingForStore('store-a'), isEmpty);
    final recovered = await journal.recover(applyLocal: (mutation) async {
      local.putIfAbsent(mutation['saleId'] as String, () => mutation['total']);
    }, storeId: 'store-a');

    expect(recovered, 1);
    expect(await outbox.pendingForStore('store-a'), hasLength(1));
    expect((storage.data['mutation-1'] as Map)['status'], 'completed');
  });

  test('recovery is scoped to a store and bounded', () async {
    // Leave two durable prepared intents by simulating an interrupted local write.
    for (final entry in [_entry(id: 'a'), _entry(id: 'b', store: 'store-b')]) {
      await expectLater(
        journal.commit(entry: entry, applyLocal: (_) async => throw StateError('offline')),
        throwsStateError,
      );
    }
    final applied = <String>[];
    final count = await journal.recover(
      storeId: 'store-a',
      limit: 1,
      applyLocal: (mutation) async => applied.add(mutation['saleId'] as String),
    );
    expect(count, 1);
    expect(applied, ['sale-1']);
    expect((storage.data['b'] as Map)['status'], 'prepared');
  });

  test('rejects reusing a mutation ID for different content', () async {
    await journal.commit(entry: _entry(), applyLocal: (_) async {});
    await expectLater(
      journal.commit(
        entry: _entry(local: const <String, Object?>{'saleId': 'sale-1', 'total': 99}),
        applyLocal: (_) async {},
      ),
      throwsStateError,
    );
  });
}
