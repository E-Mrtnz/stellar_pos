import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

class _HiveCursorStorageForTest implements CloudSyncCursorStorage {
  _HiveCursorStorageForTest(this.box);
  final Box<dynamic> box;

  @override
  Object? get(String key) => box.get(key);

  @override
  Future<void> put(String key, Object value) => box.put(key, value);

  @override
  Future<void> flush() => box.flush();
}

void main() {
  late Directory directory;
  const boxName = 'cursor_persistence_test';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stellar_cursor_');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('cursor survives closing and reopening Hive', () async {
    final box = await Hive.openBox<dynamic>(boxName);
    final cursorStore = CloudSyncCursorStore(
      boxName: boxName,
      storage: _HiveCursorStorageForTest(box),
    );
    expect(await cursorStore.advance(
      storeId: 'store-a',
      deviceId: 'device-a',
      candidate: const CloudSyncCursor(storeId: 'store-a', version: 12),
    ), isTrue);
    await Hive.close();

    Hive.init(directory.path);
    final reopenedBox = await Hive.openBox<dynamic>(boxName);
    final reopenedStore = CloudSyncCursorStore(
      boxName: boxName,
      storage: _HiveCursorStorageForTest(reopenedBox),
    );
    final restored = await reopenedStore.read(
      storeId: 'store-a',
      deviceId: 'device-a',
    );
    expect(restored?.version, 12);
  });
}
