import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_sale_acceptance_transport.dart';
import 'package:stellar_pos/core/cloud_sale_sync_coordinator.dart';
import 'package:stellar_pos/core/cloud_sales_pull.dart';
import 'package:stellar_pos/core/cloud_sync_worker.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

class _Local implements CloudSaleLocalStore {
  final Map<String, SaleRecord> values = <String, SaleRecord>{};
  @override Future<SaleRecord?> getById(String id) async => values[id];
  @override Future<void> save(SaleRecord sale) async { values[sale.id] = sale; }
}

class _Gate implements CloudSyncSessionGate {
  _Gate(this.allowed);
  final bool allowed;
  @override Future<bool> canSyncStore(String storeId) async => allowed;
}

class _Acceptance implements CloudSaleAcceptanceGateway {
  int calls = 0;
  @override
  Future<CloudSaleAcceptance> accept({required String storeId, required SaleRecord sale}) async {
    calls++;
    return CloudSaleAcceptance(
      saleId: sale.id,
      saleNumber: '101',
      ticketNumber: '101',
      status: calls == 1 ? CloudSaleAcceptanceStatus.applied : CloudSaleAcceptanceStatus.duplicate,
    );
  }
}

SaleRecord _sale({double total = 5}) => SaleRecord(
  id: 'sale-local-1',
  ticketNumber: '',
  saleNumber: null,
  createdAt: DateTime.utc(2026, 10, 16),
  clientId: null,
  clientName: '',
  paymentMethod: 'Efectivo',
  items: const <SaleItemRecord>[],
  subtotal: total,
  discountPercent: 0,
  discountAmount: 0,
  cardFeeAmount: 0,
  total: total,
  received: total,
  change: 0,
  metadata: SyncMetadata.initial(deviceId: 'device-a'),
);

void main() {
  test('acceptance assigns server number and persists it locally', () async {
    final local = _Local()..values['sale-local-1'] = _sale();
    final acceptance = _Acceptance();
    final coordinator = CloudSaleSyncCoordinator(
      acceptance: acceptance, local: local, sessionGate: _Gate(true),
    );

    final result = await coordinator.acceptSale(storeId: 'store-a', saleId: 'sale-local-1');

    expect(result.status, CloudSaleAcceptanceStatus.applied);
    expect(local.values['sale-local-1']?.saleNumber, '101');
    expect(local.values['sale-local-1']?.ticketNumber, '101');
    expect(local.values['sale-local-1']?.metadata.storeId, 'store-a');
    expect(local.values['sale-local-1']?.metadata.syncState, SyncState.synced);
  });

  test('denies acceptance without active store membership', () async {
    final local = _Local()..values['sale-local-1'] = _sale();
    final acceptance = _Acceptance();
    final coordinator = CloudSaleSyncCoordinator(
      acceptance: acceptance, local: local, sessionGate: _Gate(false),
    );
    await expectLater(
      coordinator.acceptSale(storeId: 'store-a', saleId: 'sale-local-1'),
      throwsStateError,
    );
    expect(acceptance.calls, 0);
    expect(local.values['sale-local-1']?.saleNumber, isNull);
  });

  test('retry reuses the same sale identity and stores original server number', () async {
    final local = _Local()..values['sale-local-1'] = _sale();
    final acceptance = _Acceptance();
    final coordinator = CloudSaleSyncCoordinator(
      acceptance: acceptance, local: local, sessionGate: _Gate(true),
    );
    await coordinator.acceptSale(storeId: 'store-a', saleId: 'sale-local-1');
    final second = await coordinator.acceptSale(storeId: 'store-a', saleId: 'sale-local-1');

    expect(second.status, CloudSaleAcceptanceStatus.duplicate);
    expect(acceptance.calls, 2);
    expect(local.values['sale-local-1']?.saleNumber, '101');
  });
}
