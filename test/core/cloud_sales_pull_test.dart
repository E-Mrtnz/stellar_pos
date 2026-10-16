import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_sales_pull.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

class _CursorMemory implements CloudSyncCursorStorage {
  final Map<String, Object> data = <String, Object>{};
  @override Object? get(String key) => data[key];
  @override Future<void> put(String key, Object value) async { data[key] = value; }
  @override Future<void> flush() async {}
}

class _SalesTransport implements CloudSalesPullTransport {
  _SalesTransport(this.page);
  CloudSalesPullPage page;
  int calls = 0;
  @override
  Future<CloudSalesPullPage> fetchPage({required String storeId, required int afterVersion, required int limit}) async {
    calls++;
    expect(afterVersion, page.afterVersion);
    return page;
  }
}

class _Applier implements CloudSaleRemoteApplier {
  final List<String> applied = <String>[];
  bool fail = false;
  @override
  Future<void> apply(CloudSaleChange change) async {
    if (fail) throw StateError('local write failed');
    if (!applied.contains(change.saleId)) applied.add(change.saleId);
  }
}

SaleRecord _sale(String id, {String storeId = 'store-a'}) => SaleRecord(
  id: id,
  ticketNumber: '1',
  saleNumber: '1',
  createdAt: DateTime.utc(2026, 10, 16),
  clientId: null,
  clientName: '',
  paymentMethod: 'Efectivo',
  items: const <SaleItemRecord>[],
  subtotal: 1,
  discountPercent: 0,
  discountAmount: 0,
  cardFeeAmount: 0,
  total: 1,
  received: 1,
  change: 0,
  metadata: SyncMetadata(
    createdAt: DateTime.utc(2026, 10, 16),
    updatedAt: DateTime.utc(2026, 10, 16),
    version: 1,
    schemaVersion: 1,
    syncState: SyncState.synced,
    storeId: storeId,
  ),
);

CloudSaleChange _change(String id, int version, {String storeId = 'store-a'}) => CloudSaleChange(
  storeId: storeId,
  eventId: id,
  saleId: id,
  version: version,
  localVersion: 1,
  sale: _sale(id, storeId: storeId),
);

void main() {
  late _CursorMemory cursorMemory;
  late CloudSyncCursorStore cursors;

  setUp(() {
    cursorMemory = _CursorMemory();
    cursors = CloudSyncCursorStore(storage: cursorMemory);
  });

  test('applies a complete sale page before advancing its cursor', () async {
    final transport = _SalesTransport(CloudSalesPullPage(
      storeId: 'store-a', afterVersion: 0,
      changes: [_change('sale-1', 1), _change('sale-2', 2)],
      nextCursor: 2, hasMore: true,
    ));
    final applier = _Applier();
    final coordinator = CloudSalesPullCoordinator(
      transport: transport, applier: applier, cursors: cursors,
    );

    final page = await coordinator.pullOnce(storeId: 'store-a', deviceId: 'device-a');
    expect(page.changes, hasLength(2));
    expect(applier.applied, ['sale-1', 'sale-2']);
    expect((await cursors.read(storeId: 'store-a', deviceId: 'device-a'))?.version, 2);
  });

  test('does not advance cursor if a local remote-sale upsert fails', () async {
    final transport = _SalesTransport(CloudSalesPullPage(
      storeId: 'store-a', afterVersion: 0,
      changes: [_change('sale-1', 1)], nextCursor: 1, hasMore: false,
    ));
    final applier = _Applier()..fail = true;
    final coordinator = CloudSalesPullCoordinator(
      transport: transport, applier: applier, cursors: cursors,
    );
    await expectLater(
      coordinator.pullOnce(storeId: 'store-a', deviceId: 'device-a'),
      throwsStateError,
    );
    expect(await cursors.read(storeId: 'store-a', deviceId: 'device-a'), isNull);
  });

  test('rejects cross-store changes before local application', () async {
    final transport = _SalesTransport(CloudSalesPullPage(
      storeId: 'store-a', afterVersion: 0,
      changes: [_change('sale-1', 1, storeId: 'store-b')],
      nextCursor: 1, hasMore: false,
    ));
    final applier = _Applier();
    final coordinator = CloudSalesPullCoordinator(
      transport: transport, applier: applier, cursors: cursors,
    );
    await expectLater(
      coordinator.pullOnce(storeId: 'store-a', deviceId: 'device-a'),
      throwsFormatException,
    );
    expect(applier.applied, isEmpty);
    expect(await cursors.read(storeId: 'store-a', deviceId: 'device-a'), isNull);
  });
}
