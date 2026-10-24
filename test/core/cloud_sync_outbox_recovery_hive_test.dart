import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:stellar_pos/core/cloud_sync_outbox.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

class _HiveOutboxRecoveryStorage implements CloudSyncOutboxStorage {
  _HiveOutboxRecoveryStorage(this.box);
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
  const boxName = 'outbox_recovery_test';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stellar_outbox_recovery_');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('interrupted in-flight event remains recoverable after process restart', () async {
    final box = await Hive.openBox<dynamic>(boxName);
    final outbox = CloudSyncOutbox(storage: _HiveOutboxRecoveryStorage(box));
    await outbox.enqueue(CloudSyncEvent(
      eventId: 'evt-interrupted',
      storeId: 'store-a',
      entityType: 'product',
      entityId: 'product-7',
      operation: CloudSyncOperation.update,
      localVersion: 7,
      createdAt: DateTime.utc(2026, 10, 14, 12),
    ));
    await outbox.markInFlight('evt-interrupted', storeId: 'store-a');
    await Hive.close();

    Hive.init(directory.path);
    final reopenedBox = await Hive.openBox<dynamic>(boxName);
    final reopened = CloudSyncOutbox(
      storage: _HiveOutboxRecoveryStorage(reopenedBox),
    );
    expect(await reopened.recoverInterruptedEvents(), 1);
    final pending = await reopened.pendingForStore('store-a');
    expect(pending, hasLength(1));
    expect(pending.single.eventId, 'evt-interrupted');
    expect(pending.single.status, CloudSyncEventStatus.pending);
    expect(pending.single.attemptCount, 1);
  });
  test('scheduled retry timestamp survives Hive close and reopen', () async {
    final box = await Hive.openBox<dynamic>(boxName);
    final outbox = CloudSyncOutbox(storage: _HiveOutboxRecoveryStorage(box));
    await outbox.enqueue(CloudSyncEvent(
      eventId: 'evt-retry-persisted',
      storeId: 'store-a',
      entityType: 'product',
      entityId: 'product-9',
      operation: CloudSyncOperation.update,
      localVersion: 9,
      createdAt: DateTime.utc(2026, 10, 20, 13),
    ));

    await outbox.markBlocked('evt-retry-persisted', storeId: 'store-a');
    await outbox.retry(
      'evt-retry-persisted',
      delay: const Duration(minutes: 5),
    );
    final beforeRestart = DateTime.parse(
      (box.get('evt-retry-persisted') as Map)['nextAttemptAt'] as String,
    );
    await Hive.close();

    Hive.init(directory.path);
    final reopenedBox = await Hive.openBox<dynamic>(boxName);
    final reopened = CloudSyncOutbox(
      storage: _HiveOutboxRecoveryStorage(reopenedBox),
    );
    final pending = await reopened.pendingForStore('store-a');

    expect(pending, hasLength(1));
    expect(pending.single.eventId, 'evt-retry-persisted');
    expect(pending.single.attemptCount, 1);
    expect(pending.single.nextAttemptAt, beforeRestart);
    expect(pending.single.nextAttemptAt!.isAfter(DateTime.now().toUtc()), isTrue);
  });

}
