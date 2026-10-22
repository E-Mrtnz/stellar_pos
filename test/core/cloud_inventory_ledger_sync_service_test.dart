import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_inventory_ledger_pull.dart';
import 'package:stellar_pos/core/cloud_inventory_ledger_sync_service.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_worker.dart';

class _CursorStorage implements CloudSyncCursorStorage {
  final Map<String, Object> values = <String, Object>{};
  @override
  Object? get(String key) => values[key];
  @override
  Future<void> put(String key, Object value) async {
    values[key] = value;
  }
  @override
  Future<void> flush() async {}
}

class _Gate implements CloudSyncSessionGate {
  _Gate(this.allowed);
  final bool allowed;
  int calls = 0;
  @override
  Future<bool> canSyncStore(String storeId) async {
    calls++;
    return allowed;
  }
}

class _Transport implements CloudInventoryLedgerPullTransport {
  int calls = 0;
  @override
  Future<CloudInventoryLedgerPage> fetchPage({
    required String storeId,
    required int afterVersion,
    required int limit,
  }) async {
    calls++;
    return CloudInventoryLedgerPage(
      storeId: storeId,
      afterVersion: afterVersion,
      changes: const <CloudInventoryLedgerChange>[],
      nextCursor: afterVersion,
      hasMore: false,
    );
  }
}

class _Applier implements CloudInventoryLedgerChangeApplier {
  @override
  Future<void> apply(CloudInventoryLedgerChange change) async {}
}

void main() {
  test('inactive membership pauses before any remote pull', () async {
    final gate = _Gate(false);
    final transport = _Transport();
    final service = CloudInventoryLedgerSyncService(
      coordinator: CloudInventoryLedgerPullCoordinator(
        transport: transport,
        applier: _Applier(),
        cursors: CloudSyncCursorStore(storage: _CursorStorage()),
      ),
      sessionGate: gate,
    );

    final result = await service.pullOnce(
      storeId: 'store-a',
      deviceId: 'device-a',
    );

    expect(result, isNull);
    expect(gate.calls, 1);
    expect(transport.calls, 0);
  });

  test('active membership permits a bounded explicit pull', () async {
    final gate = _Gate(true);
    final transport = _Transport();
    final service = CloudInventoryLedgerSyncService(
      coordinator: CloudInventoryLedgerPullCoordinator(
        transport: transport,
        applier: _Applier(),
        cursors: CloudSyncCursorStore(storage: _CursorStorage()),
      ),
      sessionGate: gate,
    );

    final result = await service.pullOnce(
      storeId: 'store-a',
      deviceId: 'device-a',
      limit: 25,
    );

    expect(result?.storeId, 'store-a');
    expect(transport.calls, 1);
  });

  test('rejects invalid store and device identifiers before checking membership', () async {
    final gate = _Gate(true);
    final service = CloudInventoryLedgerSyncService(
      coordinator: CloudInventoryLedgerPullCoordinator(
        transport: _Transport(),
        applier: _Applier(),
        cursors: CloudSyncCursorStore(storage: _CursorStorage()),
      ),
      sessionGate: gate,
    );

    await expectLater(
      service.pullOnce(storeId: 'store/a', deviceId: 'device-a'),
      throwsArgumentError,
    );
    expect(gate.calls, 0);
  });
}
