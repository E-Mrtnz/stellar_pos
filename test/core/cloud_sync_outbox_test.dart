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
      expect(
        await outbox.claimForDelivery(
          eventId: 'evt-1',
          storeId: 'store-a',
          now: firstTime,
        ),
        isTrue,
      );
      await outbox.markDelivered('evt-1', storeId: 'store-a');
      await outbox.enqueue(event());

      expect(storage.data, hasLength(1));
      expect(storage.data['evt-1'], containsPair('status', 'delivered'));
      expect(storage.flushCount, 3);
    });

    test('rejects a non-pending event even when its ID already exists', () async {
      await outbox.enqueue(event());

      await expectLater(
        outbox.enqueue(event().copyWith(status: CloudSyncEventStatus.delivered)),
        throwsA(isA<StateError>()),
      );

      expect(storage.data['evt-1'], containsPair('status', 'pending'));
      expect(storage.flushCount, 1);
    });

    test('rejects invalid metadata even when its ID already exists', () async {
      await outbox.enqueue(event());

      await expectLater(
        outbox.enqueue(event().copyWith(attemptCount: -1)),
        throwsA(isA<StateError>()),
      );

      expect(storage.data['evt-1'], containsPair('attemptCount', 0));
      expect(storage.flushCount, 1);
    });

    test('rejects an event ID collision across stores without overwriting either identity', () async {
      await outbox.enqueue(event(eventId: 'shared-event', storeId: 'store-a'));

      await expectLater(
        outbox.enqueue(event(eventId: 'shared-event', storeId: 'store-b')),
        throwsA(isA<StateError>()),
      );

      expect(storage.data, hasLength(1));
      expect(storage.data['shared-event'], containsPair('storeId', 'store-a'));
      expect(await outbox.pendingForStore('store-a'), hasLength(1));
      expect(await outbox.pendingForStore('store-b'), isEmpty);
      expect(storage.flushCount, 1);
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

    test('serializes concurrent writes across outbox instances', () async {
      final secondOutbox = CloudSyncOutbox(storage: storage);

      final results = await Future.wait<Object?>([
        outbox.enqueue(event(entityId: 'product-1')).then<Object?>((_) => null),
        secondOutbox
            .enqueue(event(entityId: 'product-2'))
            .then<Object?>((_) => null, onError: (Object error) => error),
      ]);

      expect(results.whereType<StateError>(), hasLength(1));
      expect(storage.data, hasLength(1));
      final stored = storage.data['evt-1']! as Map<String, Object?>;
      expect(stored['entityId'], anyOf('product-1', 'product-2'));
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
      await outbox.markInFlight('earlier', storeId: 'store-a');

      final pending = await outbox.pendingForStore('store-a');
      expect(pending.map((e) => e.eventId), <String>['later']);
      expect(await outbox.pendingForStore('store-b'),
          hasLength(1));
    });

    test('corrupt records owned by another store do not block scoped reads or recovery', () async {
      await outbox.enqueue(event(eventId: 'store-a-event', storeId: 'store-a'));
      await outbox.markInFlight('store-a-event', storeId: 'store-a');
      storage.data['corrupt-store-b'] = <String, Object?>{
        'eventId': 'corrupt-store-b',
        'storeId': 'store-b',
        'status': 'inFlight',
        'payload': 'malformed',
      };

      expect(await outbox.pendingForStore('store-a'), isEmpty);
      expect(
        await outbox.recoverInterruptedEvents(storeId: 'store-a'),
        1,
      );
      expect(
        storage.data['store-a-event'],
        containsPair('status', 'pending'),
      );
      expect(
        storage.data['corrupt-store-b'],
        containsPair('payload', 'malformed'),
      );
    });

    test('only one outbox instance can claim an event for delivery', () async {
      await outbox.enqueue(event());
      final secondOutbox = CloudSyncOutbox(storage: storage);

      final claims = await Future.wait<bool>([
        outbox.claimForDelivery(
          eventId: 'evt-1',
          storeId: 'store-a',
          now: firstTime,
        ),
        secondOutbox.claimForDelivery(
          eventId: 'evt-1',
          storeId: 'store-a',
          now: firstTime,
        ),
      ]);

      expect(claims.where((claimed) => claimed), hasLength(1));
      expect(storage.data['evt-1'], containsPair('status', 'inFlight'));
    });

    test('claim rejects another store and respects retry time', () async {
      await outbox.enqueue(event().copyWith(
        nextAttemptAt: DateTime.utc(2026, 10, 15),
      ));

      expect(
        await outbox.claimForDelivery(
          eventId: 'evt-1',
          storeId: 'store-b',
          now: firstTime,
        ),
        isFalse,
      );
      expect(
        await outbox.claimForDelivery(
          eventId: 'evt-1',
          storeId: 'store-a',
          now: firstTime,
        ),
        isFalse,
      );
      expect(
        await outbox.claimForDelivery(
          eventId: 'evt-1',
          storeId: 'store-a',
          now: DateTime.utc(2026, 10, 16),
        ),
        isTrue,
      );
    });

    test('status changes remove event from pending results', () async {
      await outbox.enqueue(event());
      expect(
        await outbox.claimForDelivery(
          eventId: 'evt-1',
          storeId: 'store-a',
          now: firstTime,
        ),
        isTrue,
      );
      expect(await outbox.pendingForStore('store-a'), isEmpty);

      await outbox.markDelivered('evt-1', storeId: 'store-a');
      expect(storage.data['evt-1'], containsPair('status', 'delivered'));
      expect(await outbox.pendingForStore('store-a'), isEmpty);
    });

    test('cannot mark a pending event delivered without claiming it', () async {
      await outbox.enqueue(event());

      await expectLater(
        outbox.markDelivered('evt-1', storeId: 'store-a'),
        throwsA(isA<StateError>()),
      );
      expect(storage.data['evt-1'], containsPair('status', 'pending'));
    });

    test('store-scoped status changes reject events owned by another store', () async {
      await outbox.enqueue(event(eventId: 'evt-b', storeId: 'store-b'));
      await outbox.claimForDelivery(
        eventId: 'evt-b',
        storeId: 'store-b',
        now: firstTime,
      );

      await expectLater(
        outbox.markDelivered('evt-b', storeId: 'store-a'),
        throwsA(isA<StateError>()),
      );
      expect(storage.data['evt-b'], containsPair('status', 'inFlight'));

      await outbox.markBlocked('evt-b', storeId: 'store-b');
      await expectLater(
        outbox.retry('evt-b', storeId: 'store-a'),
        throwsA(isA<StateError>()),
      );
      expect(storage.data['evt-b'], containsPair('status', 'blocked'));
      expect(storage.data['evt-b'], containsPair('attemptCount', 0));
    });

    test('cannot retry an event already delivered', () async {
      await outbox.enqueue(event());
      await outbox.claimForDelivery(
        eventId: 'evt-1',
        storeId: 'store-a',
        now: firstTime,
      );
      await outbox.markDelivered('evt-1', storeId: 'store-a');

      await expectLater(
        outbox.retry('evt-1', storeId: 'store-a'),
        throwsA(isA<StateError>()),
      );
      expect(storage.data['evt-1'], containsPair('status', 'delivered'));
    });

    test('retry restores pending status and increments attempts', () async {
      await outbox.enqueue(event());
      await outbox.markBlocked('evt-1', storeId: 'store-a');
      await outbox.retry('evt-1', storeId: 'store-a');

      expect(storage.data['evt-1'], containsPair('status', 'pending'));
      expect(storage.data['evt-1'], containsPair('attemptCount', 1));
      expect((storage.data['evt-1']! as Map<String, Object?>)['nextAttemptAt'], isA<String>());
      expect(DateTime.parse((storage.data['evt-1']! as Map<String, Object?>)['nextAttemptAt'] as String),
          isA<DateTime>());
      expect((await outbox.pendingForStore('store-a')).single.eventId,
          'evt-1');
    });

    test('rejects negative retry delays without changing the event', () async {
      await outbox.enqueue(event());
      await outbox.markBlocked('evt-1', storeId: 'store-a');

      await expectLater(
        outbox.retry('evt-1', storeId: 'store-a', delay: const Duration(seconds: -1)),
        throwsArgumentError,
      );

      expect(storage.data['evt-1'], containsPair('status', 'blocked'));
      expect(storage.data['evt-1'], containsPair('attemptCount', 0));
      expect(storage.flushCount, 2);
    });

    test('recovers interrupted in-flight events without crossing stores', () async {
      await outbox.enqueue(event());
      await outbox.enqueue(event(eventId: 'evt-2', storeId: 'store-b'));
      await outbox.markInFlight('evt-1', storeId: 'store-a');

      final recovered = await outbox.recoverInterruptedEvents();

      expect(recovered, 1);
      expect(storage.data['evt-1'], containsPair('status', 'pending'));
      expect(storage.data['evt-1'], containsPair('attemptCount', 1));
      expect(storage.data['evt-2'], containsPair('status', 'pending'));
      expect(await outbox.pendingForStore('store-a'), hasLength(1));
    });

    test('clears stale retry deadlines when recovering interrupted events', () async {
      await outbox.enqueue(event().copyWith(
        nextAttemptAt: DateTime.utc(2099, 1, 1),
      ));
      await outbox.markInFlight('evt-1', storeId: 'store-a');

      expect(await outbox.recoverInterruptedEvents(), 1);

      final stored = storage.data['evt-1']! as Map<String, Object?>;
      expect(stored['status'], 'pending');
      expect(stored['nextAttemptAt'], isNull);
      expect(
        await outbox.claimForDelivery(
          eventId: 'evt-1',
          storeId: 'store-a',
          now: firstTime,
        ),
        isTrue,
      );
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

    test('rejects a malformed persisted retry deadline instead of ignoring it',
        () async {
      storage.data['corrupt-deadline'] = <String, Object?>{
        'eventId': 'corrupt-deadline',
        'storeId': 'store-a',
        'entityType': 'product',
        'entityId': 'product-1',
        'operation': 'update',
        'localVersion': 1,
        'createdAt': firstTime.toIso8601String(),
        'status': 'pending',
        'attemptCount': 0,
        'nextAttemptAt': 42,
        'payload': <String, Object?>{},
      };

      await expectLater(
        outbox.pendingForStore('store-a'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects malformed persisted payload instead of replacing it with empty data',
        () async {
      storage.data['corrupt-payload'] = <String, Object?>{
        'eventId': 'corrupt-payload',
        'storeId': 'store-a',
        'entityType': 'product',
        'entityId': 'product-1',
        'operation': 'update',
        'localVersion': 1,
        'createdAt': firstTime.toIso8601String(),
        'status': 'pending',
        'attemptCount': 0,
        'nextAttemptAt': null,
        'payload': 'not-a-map',
      };

      await expectLater(
        outbox.pendingForStore('store-a'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects persisted events with a negative attempt counter', () async {
      storage.data['negative-attempts'] = <String, Object?>{
        'eventId': 'negative-attempts',
        'storeId': 'store-a',
        'entityType': 'product',
        'entityId': 'product-1',
        'operation': 'update',
        'localVersion': 1,
        'createdAt': firstTime.toIso8601String(),
        'status': 'pending',
        'attemptCount': -1,
        'nextAttemptAt': null,
        'payload': <String, Object?>{},
      };

      await expectLater(
        outbox.pendingForStore('store-a'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects persisted events with an invalid payload value', () async {
      storage.data['invalid-payload-value'] = <String, Object?>{
        'eventId': 'invalid-payload-value',
        'storeId': 'store-a',
        'entityType': 'product',
        'entityId': 'product-1',
        'operation': 'update',
        'localVersion': 1,
        'createdAt': firstTime.toIso8601String(),
        'status': 'pending',
        'attemptCount': 0,
        'nextAttemptAt': null,
        'payload': <String, Object?>{'price': double.nan},
      };

      await expectLater(
        outbox.pendingForStore('store-a'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects persisted events with a negative local version', () async {
      storage.data['negative-version'] = <String, Object?>{
        'eventId': 'negative-version',
        'storeId': 'store-a',
        'entityType': 'product',
        'entityId': 'product-1',
        'operation': 'update',
        'localVersion': -1,
        'createdAt': firstTime.toIso8601String(),
        'status': 'pending',
        'attemptCount': 0,
        'nextAttemptAt': null,
        'payload': <String, Object?>{},
      };

      await expectLater(
        outbox.pendingForStore('store-a'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects persisted events with blank store identity', () async {
      storage.data['blank-store'] = <String, Object?>{
        'eventId': 'blank-store',
        'storeId': '  ',
        'entityType': 'product',
        'entityId': 'product-1',
        'operation': 'update',
        'localVersion': 1,
        'createdAt': firstTime.toIso8601String(),
        'status': 'pending',
        'attemptCount': 0,
        'nextAttemptAt': null,
        'payload': <String, Object?>{},
      };

      await expectLater(
        outbox.pendingForStore('store-a'),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects persisted events with a missing payload instead of using empty data', () async {
      storage.data['missing-payload'] = <String, Object?>{
        'eventId': 'missing-payload',
        'storeId': 'store-a',
        'entityType': 'product',
        'entityId': 'product-1',
        'operation': 'update',
        'localVersion': 1,
        'createdAt': firstTime.toIso8601String(),
        'status': 'pending',
        'attemptCount': 0,
        'nextAttemptAt': null,
      };

      await expectLater(
        outbox.pendingForStore('store-a'),
        throwsA(isA<StateError>()),
      );
    });

    test('unknown event status update fails explicitly', () async {
      await expectLater(
        outbox.markDelivered('missing', storeId: 'store-a'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
