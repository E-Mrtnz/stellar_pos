import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_ledger_sync.dart';
import 'package:stellar_pos/core/cloud_ledger_sync_coordinator.dart';
import 'package:stellar_pos/core/cloud_sync_worker.dart';

class _Gate implements CloudSyncSessionGate {
  _Gate(this.allowed);
  final bool allowed;
  @override
  Future<bool> canSyncStore(String storeId) async => allowed;
}

class _Gateway implements CloudLedgerGateway {
  int calls = 0;
  @override
  Future<CloudLedgerAcceptance> append({
    required String storeId,
    required CloudLedgerEntityType entityType,
    required String entityId,
    required Map<String, dynamic> entry,
  }) async {
    calls++;
    return CloudLedgerAcceptance(
      entityType: entityType,
      entityId: entityId,
      version: 3,
      duplicate: false,
    );
  }

  @override
  Future<CloudLedgerPullPage> pull({
    required String storeId,
    required int afterVersion,
    int limit = 50,
  }) async => CloudLedgerPullPage(
    storeId: storeId,
    afterVersion: afterVersion,
    nextCursor: afterVersion,
    hasMore: false,
    changes: const <CloudLedgerChange>[],
  );
}

void main() {
  test('requires active membership before sending a ledger entry', () async {
    final gateway = _Gateway();
    final coordinator = CloudLedgerSyncCoordinator(
      gateway: gateway,
      sessionGate: _Gate(false),
    );

    await expectLater(
      coordinator.append(
        storeId: 'store-a',
        entityType: CloudLedgerEntityType.inventoryMovement,
        entityId: 'move-1',
        entry: <String, dynamic>{'id': 'move-1', 'quantityDelta': 2},
      ),
      throwsStateError,
    );
    expect(gateway.calls, 0);
  });

  test('sends stable entry ID only after session gate passes', () async {
    final gateway = _Gateway();
    final coordinator = CloudLedgerSyncCoordinator(
      gateway: gateway,
      sessionGate: _Gate(true),
    );

    final result = await coordinator.append(
      storeId: 'store-a',
      entityType: CloudLedgerEntityType.inventoryMovement,
      entityId: 'move-1',
      entry: <String, dynamic>{'id': 'move-1', 'quantityDelta': 2},
    );

    expect(gateway.calls, 1);
    expect(result.entityId, 'move-1');
    expect(result.version, 3);
  });

  test('rejects unstable identity before network call', () async {
    final gateway = _Gateway();
    final coordinator = CloudLedgerSyncCoordinator(
      gateway: gateway,
      sessionGate: _Gate(true),
    );

    await expectLater(
      coordinator.append(
        storeId: 'store-a',
        entityType: CloudLedgerEntityType.purchase,
        entityId: 'purchase-1',
        entry: <String, dynamic>{'id': 'different-id'},
      ),
      throwsArgumentError,
    );
    expect(gateway.calls, 0);
  });
}
