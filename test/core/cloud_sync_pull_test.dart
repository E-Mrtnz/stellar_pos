import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';
import 'package:stellar_pos/core/cloud_sync_pull.dart';

class _MemoryCursorStorage implements CloudSyncCursorStorage {
  final Map<String, Object> data = <String, Object>{};
  int flushes = 0;
  @override
  Object? get(String key) => data[key];
  @override
  Future<void> put(String key, Object value) async { data[key] = value; }
  @override
  Future<void> flush() async { flushes++; }
}

class _FakePullTransport implements CloudSyncSyntheticPullTransport {
  _FakePullTransport(this.page);
  final CloudSyncSyntheticPullPage page;
  int calls = 0;
  int? lastCursor;
  @override
  Future<CloudSyncSyntheticPullPage> fetchPage({
    required String storeId,
    required int afterVersion,
    required int limit,
  }) async {
    calls++;
    lastCursor = afterVersion;
    return page;
  }
}

class _FakeApplier implements CloudSyncSyntheticChangeApplier {
  _FakeApplier({this.failAt});
  final int? failAt;
  final List<String> applied = <String>[];
  @override
  Future<void> apply(CloudSyncSyntheticChange change) async {
    applied.add(change.eventId);
    if (applied.length == failAt) throw StateError('simulated apply failure');
  }
}

CloudSyncSyntheticChange _change(int version, String eventId) =>
    CloudSyncSyntheticChange(
      storeId: 'store-a',
      eventId: eventId,
      entityId: 'entity-$version',
      version: version,
      localVersion: 1,
      payload: <String, Object?>{'value': 'value-$version'},
    );

void main() {
  group('CloudSyncPullCoordinator', () {
    test('applies a complete page before committing its cursor', () async {
      final cursorStorage = _MemoryCursorStorage();
      final cursors = CloudSyncCursorStore(storage: cursorStorage);
      final transport = _FakePullTransport(CloudSyncSyntheticPullPage(
        storeId: 'store-a',
        afterVersion: 0,
        changes: <CloudSyncSyntheticChange>[
          _change(1, 'event-1'),
          _change(2, 'event-2'),
        ],
        nextCursor: 2,
        hasMore: false,
      ));
      final applier = _FakeApplier();
      final coordinator = CloudSyncPullCoordinator(
        transport: transport,
        applier: applier,
        cursors: cursors,
      );

      final page = await coordinator.pullOnce(
        storeId: 'store-a',
        deviceId: 'device-a',
      );

      expect(page.nextCursor, 2);
      expect(applier.applied, <String>['event-1', 'event-2']);
      expect((await cursors.read(storeId: 'store-a', deviceId: 'device-a'))?.version, 2);
      expect(transport.lastCursor, 0);
    });

    test('does not advance the cursor if applying any change fails', () async {
      final cursors = CloudSyncCursorStore(storage: _MemoryCursorStorage());
      final transport = _FakePullTransport(CloudSyncSyntheticPullPage(
        storeId: 'store-a',
        afterVersion: 0,
        changes: <CloudSyncSyntheticChange>[
          _change(1, 'event-1'),
          _change(2, 'event-2'),
        ],
        nextCursor: 2,
        hasMore: false,
      ));
      final coordinator = CloudSyncPullCoordinator(
        transport: transport,
        applier: _FakeApplier(failAt: 2),
        cursors: cursors,
      );

      await expectLater(
        coordinator.pullOnce(storeId: 'store-a', deviceId: 'device-a'),
        throwsA(isA<StateError>()),
      );
      expect(await cursors.read(storeId: 'store-a', deviceId: 'device-a'), isNull);
    });

    test('rejects cross-store or non-synthetic changes before applying', () async {
      final cursors = CloudSyncCursorStore(storage: _MemoryCursorStorage());
      final bad = CloudSyncSyntheticChange(
        storeId: 'other-store',
        eventId: 'event-1',
        entityId: 'entity-1',
        version: 1,
        payload: <String, Object?>{'value': 'test'},
      );
      final transport = _FakePullTransport(CloudSyncSyntheticPullPage(
        storeId: 'store-a',
        afterVersion: 0,
        changes: <CloudSyncSyntheticChange>[bad],
        nextCursor: 1,
        hasMore: false,
      ));
      final applier = _FakeApplier();
      final coordinator = CloudSyncPullCoordinator(
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
  });
}
