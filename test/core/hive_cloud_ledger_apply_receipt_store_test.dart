import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:stellar_pos/core/hive_cloud_ledger_apply_receipt_store.dart';

void main() {
  late Directory directory;
  const boxName = 'ledger_apply_receipts_test';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('stellar_ledger_receipts_');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('receipt survives closing and reopening Hive', () async {
    final box = await Hive.openBox<dynamic>(boxName);
    final store = HiveCloudLedgerApplyReceiptStore.forBox(boxName, box);
    await store.put('inventoryMovement_move-1', <String, Object?>{
      'storeId': 'store-a',
      'entityType': 'inventoryMovement',
      'entityId': 'move-1',
      'version': 4,
      'fingerprint': '{"id":"move-1","quantityDelta":2}',
    });
    await store.flush();
    await Hive.close();

    Hive.init(directory.path);
    final reopenedBox = await Hive.openBox<dynamic>(boxName);
    final reopened = HiveCloudLedgerApplyReceiptStore.forBox(boxName, reopenedBox);

    expect(
      (reopened.get('inventoryMovement_move-1') as Map)['version'],
      4,
    );
    expect(
      (reopened.get('inventoryMovement_move-1') as Map)['storeId'],
      'store-a',
    );
  });
}
