import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:stellar_pos/core/cloud_sync_outbox.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

class _HiveOutboxStorage implements CloudSyncOutboxStorage {
  _HiveOutboxStorage(this.box);
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
  const boxName = 'outbox_persistence_test';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stellar_outbox_');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('pending event survives closing and reopening Hive', () async {
    final box = await Hive.openBox<dynamic>(boxName);
    final outbox = CloudSyncOutbox(storage: _HiveOutboxStorage(box));
    final createdAt = DateTime.utc(2026, 10, 14, 10);
    await outbox.enqueue(CloudSyncEvent(
      eventId: 'evt-persistent', storeId: 'store-a',
      entityType: 'product', entityId: 'product-1',
      operation: CloudSyncOperation.update, localVersion: 3,
      createdAt: createdAt,
    ));

    await Hive.close();
    Hive.init(directory.path);
    final reopenedBox = await Hive.openBox<dynamic>(boxName);
    final reopened = CloudSyncOutbox(storage: _HiveOutboxStorage(reopenedBox));
    final pending = await reopened.pendingForStore('store-a');

    expect(pending, hasLength(1));
    expect(pending.single.eventId, 'evt-persistent');
    expect(pending.single.localVersion, 3);
    expect(pending.single.status, CloudSyncEventStatus.pending);
    expect(pending.single.createdAt, createdAt);
  });

  test('event payload survives closing and reopening Hive', () async {
    final box = await Hive.openBox<dynamic>(boxName);
    final outbox = CloudSyncOutbox(storage: _HiveOutboxStorage(box));
    await outbox.enqueue(CloudSyncEvent(
      eventId: 'evt-payload',
      storeId: 'store-a',
      entityType: 'syntheticTestValue',
      entityId: 'synthetic-1',
      operation: CloudSyncOperation.update,
      localVersion: 1,
      createdAt: DateTime.utc(2026, 10, 14, 12),
      payload: <String, Object?>{
        'value': 'persisted',
        'details': <String, Object?>{'count': 2},
      },
    ));
    await Hive.close();

    Hive.init(directory.path);
    final reopenedBox = await Hive.openBox<dynamic>(boxName);
    final reopened = CloudSyncOutbox(storage: _HiveOutboxStorage(reopenedBox));
    final event = (await reopened.pendingForStore('store-a')).single;

    expect(event.payload['value'], 'persisted');
    expect((event.payload['details'] as Map)['count'], 2);
  });

  test('delivered status survives closing and reopening Hive', () async {
    final box = await Hive.openBox<dynamic>(boxName);
    final outbox = CloudSyncOutbox(storage: _HiveOutboxStorage(box));
    await outbox.enqueue(CloudSyncEvent(
      eventId: 'evt-delivered', storeId: 'store-a',
      entityType: 'product', entityId: 'product-2',
      operation: CloudSyncOperation.update, localVersion: 1,
      createdAt: DateTime.utc(2026, 10, 14, 11),
    ));
    await outbox.markInFlight('evt-delivered');
    await outbox.markDelivered('evt-delivered');
    await Hive.close();

    Hive.init(directory.path);
    final reopenedBox = await Hive.openBox<dynamic>(boxName);
    final reopened = CloudSyncOutbox(storage: _HiveOutboxStorage(reopenedBox));
    expect(await reopened.pendingForStore('store-a'), isEmpty);
    expect((reopenedBox.get('evt-delivered') as Map)['status'], 'delivered');
  });
}
