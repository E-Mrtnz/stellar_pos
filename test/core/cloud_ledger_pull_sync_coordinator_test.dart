import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_ledger_pull_sync_coordinator.dart';
import 'package:stellar_pos/core/cloud_ledger_sync.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_worker.dart';

class _Gate implements CloudSyncSessionGate {
  _Gate(this.allowed);
  final bool allowed;
  @override
  Future<bool> canSyncStore(String storeId) async => allowed;
}

class _CursorStorage implements CloudSyncCursorStorage {
  final Map<String, Object?> values = <String, Object?>{};
  @override
  Object? get(String key) => values[key];
  @override
  Future<void> put(String key, Object value) async => values[key] = value;
  @override
  Future<void> flush() async {}
}

class _Gateway implements CloudLedgerGateway {
  int pulls = 0;
  @override
  Future<CloudLedgerAcceptance> append({
    required String storeId,
    required CloudLedgerEntityType entityType,
    required String entityId,
    required Map<String, dynamic> entry,
  }) async => CloudLedgerAcceptance(
    entityType: entityType, entityId: entityId, version: 1, duplicate: false,
  );

  @override
  Future<CloudLedgerPullPage> pull({
    required String storeId,
    required int afterVersion,
    int limit = 50,
  }) async {
    pulls++;
    return CloudLedgerPullPage(
      storeId: storeId,
      afterVersion: afterVersion,
      nextCursor: afterVersion,
      hasMore: false,
      changes: const <CloudLedgerChange>[],
    );
  }
}

class _Applier implements CloudLedgerRemoteApplier {
  @override
  Future<void> apply(CloudLedgerChange change) async {}
}

void main() {
  test('does not pull ledger changes without active membership', () async {
    final gateway = _Gateway();
    final coordinator = CloudLedgerPullSyncCoordinator(
      gateway: gateway,
      applier: _Applier(),
      cursors: CloudSyncCursorStore(storage: _CursorStorage()),
      sessionGate: _Gate(false),
    );

    final result = await coordinator.pullOnce(
      storeId: 'store-a',
      deviceId: 'device-a',
    );

    expect(result, isNull);
    expect(gateway.pulls, 0);
  });

  test('pulls only after membership gate passes', () async {
    final gateway = _Gateway();
    final coordinator = CloudLedgerPullSyncCoordinator(
      gateway: gateway,
      applier: _Applier(),
      cursors: CloudSyncCursorStore(storage: _CursorStorage()),
      sessionGate: _Gate(true),
    );

    final result = await coordinator.pullOnce(
      storeId: 'store-a',
      deviceId: 'device-a',
    );

    expect(result?.storeId, 'store-a');
    expect(gateway.pulls, 1);
  });
}
