import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_sync_outbox.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';
import 'package:stellar_pos/core/cloud_sync_worker.dart';

class _MemoryStorage implements CloudSyncOutboxStorage {
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

class _Gate implements CloudSyncSessionGate {
  _Gate(this.allowed);
  final bool allowed;
  @override
  Future<bool> canSyncStore(String storeId) async => allowed;
}

class _Transport implements CloudSyncTransport {
  _Transport(this.result);
  final Future<CloudSyncDeliveryStatus> Function(CloudSyncEvent) result;
  int calls = 0;
  @override
  Future<CloudSyncDeliveryStatus> send(CloudSyncEvent event) {
    calls++;
    return result(event);
  }
}

CloudSyncEvent _event({
  String id = 'event-1',
  String type = 'syntheticTestValue',
  Map<String, Object?> payload = const <String, Object?>{'value': 'test'},
}) => CloudSyncEvent(
  eventId: id,
  storeId: 'store-a',
  entityType: type,
  entityId: 'entity-1',
  operation: CloudSyncOperation.update,
  localVersion: 1,
  createdAt: DateTime.utc(2026, 10, 15),
  payload: payload,
);

void main() {
  group('CloudSyncWorker', () {
    late _MemoryStorage storage;
    late CloudSyncOutbox outbox;

    setUp(() {
      storage = _MemoryStorage();
      outbox = CloudSyncOutbox(storage: storage);
    });

    test('pauses without an active authenticated membership', () async {
      await outbox.enqueue(_event());
      final transport = _Transport((_) async => CloudSyncDeliveryStatus.applied);
      final worker = CloudSyncWorker(
        outbox: outbox,
        transport: transport,
        sessionGate: _Gate(false),
      );

      final result = await worker.runOnce(storeId: 'store-a');

      expect(result.paused, isTrue);
      expect(transport.calls, 0);
      expect((await outbox.pendingForStore('store-a')), hasLength(1));
    });

    test('recovers interrupted events only for the authorized store', () async {
      await outbox.enqueue(_event(id: 'store-a-inflight'));
      await outbox.markInFlight('store-a-inflight');
      await outbox.enqueue(_event(id: 'store-b-inflight').copyWith(storeId: 'store-b'));
      await outbox.markInFlight('store-b-inflight');

      final transport = _Transport((_) async => CloudSyncDeliveryStatus.applied);
      final worker = CloudSyncWorker(
        outbox: outbox,
        transport: transport,
        sessionGate: _Gate(true),
      );

      final result = await worker.runOnce(storeId: 'store-a');

      expect(result.applied, 1);
      expect(storage.data['store-a-inflight'], containsPair('status', 'delivered'));
      expect(storage.data['store-b-inflight'], containsPair('status', 'inFlight'));
      expect(transport.calls, 1);
    });

    test('concurrent workers claim a pending event only once', () async {
      await outbox.enqueue(_event());
      final transport = _Transport((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return CloudSyncDeliveryStatus.applied;
      });
      final first = CloudSyncWorker(
        outbox: outbox,
        transport: transport,
        sessionGate: _Gate(true),
      );
      final second = CloudSyncWorker(
        outbox: outbox,
        transport: transport,
        sessionGate: _Gate(true),
      );

      final results = await Future.wait([
        first.runOnce(storeId: 'store-a'),
        second.runOnce(storeId: 'store-a'),
      ]);

      expect(transport.calls, 1);
      expect(results.fold<int>(0, (sum, result) => sum + result.applied), 1);
      expect(storage.data['event-1'], containsPair('status', 'delivered'));
    });

    test('marks a confirmed synthetic event delivered', () async {
      await outbox.enqueue(_event());
      final transport = _Transport((_) async => CloudSyncDeliveryStatus.applied);
      final worker = CloudSyncWorker(
        outbox: outbox,
        transport: transport,
        sessionGate: _Gate(true),
      );

      final result = await worker.runOnce(storeId: 'store-a');

      expect(result.applied, 1);
      expect(result.blocked, 0);
      expect(transport.calls, 1);
      expect(storage.data['event-1'], containsPair('status', 'delivered'));
    });

    test('delivers a validated immutable inventory movement', () async {
      final movement = CloudSyncEvent(
        eventId: 'inventory-movement-movement-1',
        storeId: 'store-a',
        entityType: 'inventoryMovement',
        entityId: 'movement-1',
        operation: CloudSyncOperation.create,
        localVersion: 1,
        createdAt: DateTime.utc(2026, 10, 15),
        payload: <String, Object?>{
          'movementId': 'movement-1',
          'productId': 'product-1',
          'delta': 4,
          'reason': 'restock',
          'occurredAt': DateTime.utc(2026, 10, 15).toIso8601String(),
          'localVersion': 1,
        },
      );
      await outbox.enqueue(movement);
      final transport = _Transport((event) async {
        expect(event.entityType, 'inventoryMovement');
        expect(event.operation, CloudSyncOperation.create);
        return CloudSyncDeliveryStatus.applied;
      });
      final worker = CloudSyncWorker(
        outbox: outbox,
        transport: transport,
        sessionGate: _Gate(true),
      );

      final result = await worker.runOnce(storeId: 'store-a');

      expect(result.applied, 1);
      expect(result.blocked, 0);
      expect(transport.calls, 1);
      expect(storage.data[movement.eventId], containsPair('status', 'delivered'));
    });

    test('blocks malformed inventory movement before calling transport', () async {
      final movement = CloudSyncEvent(
        eventId: 'inventory-movement-movement-2',
        storeId: 'store-a',
        entityType: 'inventoryMovement',
        entityId: 'movement-2',
        operation: CloudSyncOperation.create,
        localVersion: 1,
        createdAt: DateTime.utc(2026, 10, 15),
        payload: <String, Object?>{
          'movementId': 'movement-2',
          'productId': 'product/unsafe',
          'delta': 4,
          'reason': 'restock',
          'occurredAt': DateTime.utc(2026, 10, 15).toIso8601String(),
          'localVersion': 1,
        },
      );
      await outbox.enqueue(movement);
      final transport = _Transport((_) async => CloudSyncDeliveryStatus.applied);
      final worker = CloudSyncWorker(
        outbox: outbox,
        transport: transport,
        sessionGate: _Gate(true),
      );

      final result = await worker.runOnce(storeId: 'store-a');

      expect(result.blocked, 1);
      expect(transport.calls, 0);
      expect(storage.data[movement.eventId], containsPair('status', 'blocked'));
    });

    test('blocks commercial entities before calling the transport', () async {
      await outbox.enqueue(_event(type: 'sale'));
      final transport = _Transport((_) async => CloudSyncDeliveryStatus.applied);
      final worker = CloudSyncWorker(
        outbox: outbox,
        transport: transport,
        sessionGate: _Gate(true),
      );

      final result = await worker.runOnce(storeId: 'store-a');

      expect(result.blocked, 1);
      expect(transport.calls, 0);
      expect(storage.data['event-1'], containsPair('status', 'blocked'));
    });

    test('returns transient failures to pending with stable event ID', () async {
      await outbox.enqueue(_event());
      final transport = _Transport((_) async {
        throw const CloudSyncTransportException('offline', retryable: true);
      });
      final worker = CloudSyncWorker(
        outbox: outbox,
        transport: transport,
        sessionGate: _Gate(true),
      );

      final result = await worker.runOnce(storeId: 'store-a');

      expect(result.retried, 1);
      expect(storage.data['event-1'], containsPair('eventId', 'event-1'));
      expect(storage.data['event-1'], containsPair('status', 'pending'));
      expect(storage.data['event-1'], containsPair('attemptCount', 1));
      expect((storage.data['event-1']! as Map<String, Object?>)['nextAttemptAt'], isA<String>());

      final immediateRetry = await worker.runOnce(storeId: 'store-a');
      expect(immediateRetry.retried, 0);
      expect(transport.calls, 1);
    });

    test('a deferred retry does not starve ready events in the same batch', () async {
      await outbox.enqueue(_event(id: 'deferred').copyWith(
        nextAttemptAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      ));
      await outbox.enqueue(_event(id: 'ready'));
      final transport = _Transport((_) async => CloudSyncDeliveryStatus.applied);
      final worker = CloudSyncWorker(
        outbox: outbox,
        transport: transport,
        sessionGate: _Gate(true),
      );

      final result = await worker.runOnce(storeId: 'store-a', limit: 1);

      expect(result.applied, 1);
      expect(transport.calls, 1);
      expect(storage.data['deferred'], containsPair('status', 'pending'));
      expect(storage.data['ready'], containsPair('status', 'delivered'));
    });

    test('rejects unbounded batch sizes', () async {
      final worker = CloudSyncWorker(
        outbox: outbox,
        transport: _Transport((_) async => CloudSyncDeliveryStatus.applied),
        sessionGate: _Gate(true),
      );
      await expectLater(
        worker.runOnce(storeId: 'store-a', limit: 101),
        throwsArgumentError,
      );
    });
  });
}
