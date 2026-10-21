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
  Future<void> put(String key, Object value) async { data[key] = value; }

  @override
  Future<void> flush() async { flushCount++; }
}

void main() {
  final firstTime = DateTime.utc(2026, 10, 14, 10);
  final secondTime = DateTime.utc(2026, 10, 14, 11);

  CloudSyncEvent event({
    String eventId = 'evt-1',
    String storeId = 'store-a',
    String entityId = 'product-1',
    DateTime? createdAt,
    Map<String, Object?> payload = const <String, Object?>{},
  }) =>
      CloudSyncEvent(
        eventId: eventId,
        storeId: storeId,
        entityType: 'product',
        entityId: entityId,
        operation: CloudSyncOperation.update,
        localVersion: 1,
        createdAt: createdAt ?? firstTime,
        payload: payload,
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

    test('same event payload with different map key order is idempotent', () async {
      await outbox.enqueue(event(payload: <String, Object?>{
        'name': 'Milk',
        'details': <String, Object?>{'b': 2, 'a': 1},
      }));
      await outbox.enqueue(event(payload: <String, Object?>{
        'details': <String, Object?>{'a': 1, 'b': 2},
        'name': 'Milk',
      }));

      expect(storage.data, hasLength(1));
      expect((await outbox.pendingForStore('store-a')).single.payload['name'],
          'Milk');
    });

    test('rejects a reused event ID with different payload content', () async {
      await outbox.enqueue(event(payload: <String, Object?>{'price': 2.5}));
      await expectLater(
        outbox.enqueue(event(payload: <String, Object?>{'price': 3.0})),
        throwsA(isA<StateError>()),
      );
      expect(storage.data, hasLength(1));
    });

    test('serializes concurrent enqueues that reuse an event ID', () async {
      final results = await Future.wait<Object?>([
        outbox.enqueue(event(entityId: 'product-1')).then<Object?>((_) => null),
        outbox.enqueue(event(entityId: 'product-2')).then<Object?>((_) => null,
            onError: (Object error) => error),
      ]);

      expect(results.whereType<StateError>(), hasLength(1));
      expect(storage.data, hasLength(1));
      final stored = storage.data['evt-1']! as Map<String, Object?>;
      expect(stored['entityId'], 'product-1');
    });

    test('a new outbox instance can resume persisted pending events', () async {
      await outbox.enqueue(event());
      final restartedOutbox = CloudSyncOutbox(storage: storage);

      final pending = await restartedOutbox.pendingForStore('store-a');

      expect(pending.map((item) => item.eventId), <String>['evt-1']);
    });

    test('rejects non-pending events before persisting them', () async {
      await expectLater(
        outbox.enqueue(event().copyWith(
          status: CloudSyncEventStatus.delivered,
        )),
        throwsA(isA<StateError>()),
      );
      expect(storage.data, isEmpty);
    });

    test('rejects reuse of an event ID for a different entity', () async {
      await outbox.enqueue(event());
      await expectLater(
        outbox.enqueue(event(entityId: 'product-2')),
        throwsA(isA<StateError>()),
      );
      expect(storage.data, hasLength(1));
    });

    test('rejects reuse of an event ID with a different local version', () async {
      await outbox.enqueue(event());
      await expectLater(
        outbox.enqueue(CloudSyncEvent(
          eventId: 'evt-1',
          storeId: 'store-a',
          entityType: 'product',
          entityId: 'product-1',
          operation: CloudSyncOperation.update,
          localVersion: 2,
          createdAt: firstTime,
        )),
        throwsA(isA<StateError>()),
      );
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
      expect(storage.data['evt-1'], contains('nextAttemptAt'));
      expect(DateTime.parse((storage.data['evt-1']! as Map<String, Object?>)['nextAttemptAt'] as String),
          isA<DateTime>());
      expect((await outbox.pendingForStore('store-a')).single.eventId,
          'evt-1');
    });

    test('recovers interrupted in-flight events without crossing stores', () async {
      await outbox.enqueue(event());
      await outbox.enqueue(event(eventId: 'evt-2', storeId: 'store-b'));
      await outbox.markInFlight('evt-1');

      final recovered = await outbox.recoverInterruptedEvents();

      expect(recovered, 1);
      expect(storage.data['evt-1'], containsPair('status', 'pending'));
      expect(storage.data['evt-1'], containsPair('attemptCount', 1));
      expect(storage.data['evt-2'], containsPair('status', 'pending'));
      expect(await outbox.pendingForStore('store-a'), hasLength(1));
    });

    test('does not flush when there is nothing to recover', () async {
      await outbox.enqueue(event());
      final flushesBeforeRecovery = storage.flushCount;

      expect(await outbox.recoverInterruptedEvents(), 0);
      expect(storage.flushCount, flushesBeforeRecovery);
    });

    test('reports malformed persisted events as a clear state error', () async {
      storage.data['corrupt'] = <String, Object>{'eventId': 'corrupt'};

      await expectLater(
        outbox.pendingForStore('store-a'),
        throwsA(isA<StateError>()),
      );
    });

    test('unknown event status update fails explicitly', () async {
      await expectLater(
        outbox.markDelivered('missing'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
