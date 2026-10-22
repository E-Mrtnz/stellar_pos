import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

class _MemoryCursorStorage implements CloudSyncCursorStorage {
  final Map<String, Object> values = <String, Object>{};
  final Map<String, Object> staged = <String, Object>{};
  int flushes = 0;
  bool failNextFlush = false;

  @override
  Object? get(String key) => values[key];

  @override
  Future<void> put(String key, Object value) async {
    staged[key] = value;
  }

  @override
  Future<void> flush() async {
    flushes++;
    if (failNextFlush) {
      failNextFlush = false;
      throw StateError('simulated cursor flush failure');
    }
    values.addAll(staged);
    staged.clear();
  }
}

void main() {
  group('CloudSyncCursorStore', () {
    late _MemoryCursorStorage storage;
    late CloudSyncCursorStore cursors;

    setUp(() {
      storage = _MemoryCursorStorage();
      cursors = CloudSyncCursorStore(storage: storage);
    });

    test('persists and reads a cursor scoped to store and device', () async {
      expect(await cursors.read(storeId: 'store-a', deviceId: 'device-1'), isNull);
      expect(await cursors.advance(
        storeId: 'store-a',
        deviceId: 'device-1',
        candidate: const CloudSyncCursor(storeId: 'store-a', version: 4),
      ), isTrue);

      final stored = await cursors.read(storeId: 'store-a', deviceId: 'device-1');
      expect(stored?.version, 4);
      expect(await cursors.read(storeId: 'store-a', deviceId: 'device-2'), isNull);
      expect(await cursors.read(storeId: 'store-b', deviceId: 'device-1'), isNull);
      expect(storage.flushes, 1);
    });

    test('rejects backward and cross-store cursor movement', () async {
      await cursors.advance(
        storeId: 'store-a',
        deviceId: 'device-1',
        candidate: const CloudSyncCursor(storeId: 'store-a', version: 8),
      );

      expect(await cursors.advance(
        storeId: 'store-a',
        deviceId: 'device-1',
        candidate: const CloudSyncCursor(storeId: 'store-a', version: 7),
      ), isFalse);
      expect(await cursors.advance(
        storeId: 'store-a',
        deviceId: 'device-1',
        candidate: const CloudSyncCursor(storeId: 'store-b', version: 9),
      ), isFalse);
      expect((await cursors.read(storeId: 'store-a', deviceId: 'device-1'))?.version, 8);
      expect(storage.flushes, 1);
    });

    test('same cursor is idempotent and does not write again', () async {
      const cursor = CloudSyncCursor(storeId: 'store-a', version: 2);
      await cursors.advance(storeId: 'store-a', deviceId: 'device-1', candidate: cursor);
      final flushes = storage.flushes;
      expect(await cursors.advance(
        storeId: 'store-a',
        deviceId: 'device-1',
        candidate: cursor,
      ), isTrue);
      expect(storage.flushes, flushes);
    });

    test('does not expose an advanced cursor after durable flush fails', () async {
      storage.failNextFlush = true;
      await expectLater(
        cursors.advance(
          storeId: 'store-a',
          deviceId: 'device-1',
          candidate: const CloudSyncCursor(storeId: 'store-a', version: 3),
        ),
        throwsA(isA<StateError>()),
      );

      expect(await cursors.read(storeId: 'store-a', deviceId: 'device-1'), isNull);

      expect(await cursors.advance(
        storeId: 'store-a',
        deviceId: 'device-1',
        candidate: const CloudSyncCursor(storeId: 'store-a', version: 3),
      ), isTrue);
      expect((await cursors.read(storeId: 'store-a', deviceId: 'device-1'))?.version, 3);
    });

    test('rejects malformed persisted cursor metadata', () async {
      storage.values['device-1::store-a'] = <String, Object?>{
        'storeId': 'store-a',
        'deviceId': 'device-1',
        'version': -1,
      };
      await expectLater(
        cursors.read(storeId: 'store-a', deviceId: 'device-1'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
