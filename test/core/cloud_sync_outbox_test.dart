import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_sync_outbox.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

class _MemoryOutboxStorage implements CloudSyncOutboxStorage {
  final Map<String, Object> data = <String, Object>{};
  int flushCount = 0;

  @override
  Object? get(String key) => data[key];

  @override
  Iterable<Object?> get values => data.values;

  @override
  Future<void> put(String key, Object value) async => data[key] = value;

  @override
  Future<void> flush() async => flushCount++;
}

void main() {
  final firstTime = DateTime.utc(2026, 10, 14, 10);
  final secondTime = DateTime.utc(2026, 10, 14, 11);

  CloudSyncEvent event({
    String eventId = 'evt-1',
    String storeId = 'store-a',
    String entityId = 'product-1',
    DateTime? createdAt,
  }) =>
      CloudSyncEvent(
        eventId: eventId,
        storeId: storeId,
        entityType: 'product',
        entityId: entityId,
        operation: CloudSyncOperation.update,
        localVersion: 1,
        createdAt: createdAt ?? firstTime,
      );

  group('CloudSyncOutbox', () {
    late _MemoryOutboxStorage storage;
    late CloudSyncOutbox outbox;

    setUp(() {
      storage = _MemoryOutboxStorage();
      outbox = CloudSyncOutbox(storage: storage);
    });

    test('enqueue is idempotent for a stable event ID', () async {
      await outbox.enqueue(event());
      await outbox.markDelivered('evt-1');
      await outbox.enqueue(event());

      expect(storage.data, hasLength(1));
      expect(storage.data['evt-1'], containsPair('status', 'delivered'));
      expect(storage.flushCount, 2);
    });

    test('rejects reuse of an event ID for a different entity', () async {
      await outbox.enqueue(event());
      await expectLater(
        outbox.enqueue(event(entityId: 'product-2')),
        throwsA(isA<StateError>()),
      );
      expect(storage.data, hasLength(1));
    });

    test('pending events are isolated by store and sorted by creation time',
        () async {
      await outbox.enqueue(event(eventId: 'later', createdAt: secondTime));
      await outbox.enqueue(event(eventId: 'other', storeId: 'store-b'));
      await outbox.enqueue(event(eventId: 'earlier', createdAt: firstTime));
      await outbox.markInFlight('earlier');

      final pending = await outbox.pendingForStore('store-a');
      expect(pending.map((e) => e.eventId), <String>['later']);
      expect(await outbox.pendingForStore('store-b'),
          hasLength(1));
    });

    test('status changes remove event from pending results', () async {
      await outbox.enqueue(event());
      await outbox.markInFlight('evt-1');
      expect(await outbox.pendingForStore('store-a'), isEmpty);

      await outbox.markDelivered('evt-1');
      expect(storage.data['evt-1'], containsPair('status', 'delivered'));
      expect(await outbox.pendingForStore('store-a'), isEmpty);
    });

    test('retry restores pending status and increments attempts', () async {
      await outbox.enqueue(event());
      await outbox.markBlocked('evt-1');
      await outbox.retry('evt-1');

      expect(storage.data['evt-1'], containsPair('status', 'pending'));
      expect(storage.data['evt-1'], containsPair('attemptCount', 1));
      expect((await outbox.pendingForStore('store-a')).single.eventId,
          'evt-1');
    });

    test('unknown event status update fails explicitly', () async {
      await expectLater(
        outbox.markDelivered('missing'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
