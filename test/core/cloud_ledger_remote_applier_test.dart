import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_ledger_remote_applier.dart';
import 'package:stellar_pos/core/cloud_ledger_sync.dart';

class _MemoryReceipts implements CloudLedgerApplyReceiptStore {
  final Map<String, Object?> values = <String, Object?>{};
  int flushes = 0;
  @override
  Object? get(String eventId) => values[eventId];
  @override
  Future<void> put(String eventId, Object value) async => values[eventId] = value;
  @override
  Future<void> flush() async => flushes++;
}

CloudLedgerChange _change({
  String storeId = 'store-a',
  String id = 'move-1',
  int version = 1,
  Map<String, dynamic>? payload,
}) => CloudLedgerChange(
  storeId: storeId,
  eventId: 'inventoryMovement_$id',
  entityType: CloudLedgerEntityType.inventoryMovement,
  entityId: id,
  version: version,
  payload: payload ?? <String, dynamic>{'id': id, 'quantityDelta': 3},
);

void main() {
  group('DurableCloudLedgerRemoteApplier', () {
    test('persists a receipt after applying and skips an identical replay', () async {
      final receipts = _MemoryReceipts();
      var applications = 0;
      final applier = DurableCloudLedgerRemoteApplier(
        receipts: receipts,
        handlers: <CloudLedgerEntityType, CloudLedgerChangeHandler>{
          CloudLedgerEntityType.inventoryMovement: (_) async { applications++; },
        },
      );

      await applier.apply(_change());
      await applier.apply(_change());

      expect(applications, 1);
      expect(receipts.values, contains('store-a::inventoryMovement_move-1'));
      expect(receipts.flushes, 1);
    });

    test('serializes concurrent replays of the same event', () async {
      final receipts = _MemoryReceipts();
      var applications = 0;
      final applier = DurableCloudLedgerRemoteApplier(
        receipts: receipts,
        handlers: <CloudLedgerEntityType, CloudLedgerChangeHandler>{
          CloudLedgerEntityType.inventoryMovement: (_) async {
            applications++;
            await Future<void>.delayed(const Duration(milliseconds: 5));
          },
        },
      );

      await Future.wait<void>(List<Future<void>>.generate(
        8,
        (_) => applier.apply(_change()),
      ));

      expect(applications, 1);
      expect(receipts.values.keys, <String>['store-a::inventoryMovement_move-1']);
      expect(receipts.flushes, 1);
    });

    test('keeps identical entity IDs isolated across stores', () async {
      final receipts = _MemoryReceipts();
      var applications = 0;
      final applier = DurableCloudLedgerRemoteApplier(
        receipts: receipts,
        handlers: <CloudLedgerEntityType, CloudLedgerChangeHandler>{
          CloudLedgerEntityType.inventoryMovement: (_) async { applications++; },
        },
      );

      await applier.apply(_change(storeId: 'store-a'));
      await applier.apply(_change(storeId: 'store-b'));

      expect(applications, 2);
      expect(receipts.values.keys, contains('store-a::inventoryMovement_move-1'));
      expect(receipts.values.keys, contains('store-b::inventoryMovement_move-1'));
    });

    test('rejects reuse of a receipt ID with different payload', () async {
      final receipts = _MemoryReceipts();
      final applier = DurableCloudLedgerRemoteApplier(
        receipts: receipts,
        handlers: <CloudLedgerEntityType, CloudLedgerChangeHandler>{
          CloudLedgerEntityType.inventoryMovement: (_) async {},
        },
      );
      await applier.apply(_change());
      await expectLater(
        applier.apply(_change(payload: <String, dynamic>{
          'id': 'move-1',
          'quantityDelta': 9,
        })),
        throwsStateError,
      );
    });

    test('rejects malformed store and entity identifiers before applying', () async {
      final receipts = _MemoryReceipts();
      var applications = 0;
      final applier = DurableCloudLedgerRemoteApplier(
        receipts: receipts,
        handlers: <CloudLedgerEntityType, CloudLedgerChangeHandler>{
          CloudLedgerEntityType.inventoryMovement: (_) async { applications++; },
        },
      );

      await expectLater(
        applier.apply(_change(storeId: 'store/a')),
        throwsFormatException,
      );
      await expectLater(
        applier.apply(_change(id: 'move 1')),
        throwsFormatException,
      );

      expect(applications, 0);
      expect(receipts.values, isEmpty);
      expect(receipts.flushes, 0);
    });

    test('does not record a receipt when the local handler fails', () async {
      final receipts = _MemoryReceipts();
      final applier = DurableCloudLedgerRemoteApplier(
        receipts: receipts,
        handlers: <CloudLedgerEntityType, CloudLedgerChangeHandler>{
          CloudLedgerEntityType.inventoryMovement: (_) async {
            throw StateError('local storage unavailable');
          },
        },
      );

      await expectLater(applier.apply(_change()), throwsStateError);
      expect(receipts.values, isEmpty);
      expect(receipts.flushes, 0);
    });

    test('fails closed when no entity handler is registered', () async {
      final receipts = _MemoryReceipts();
      final applier = DurableCloudLedgerRemoteApplier(
        receipts: receipts,
        handlers: const <CloudLedgerEntityType, CloudLedgerChangeHandler>{},
      );
      await expectLater(applier.apply(_change()), throwsStateError);
      expect(receipts.values, isEmpty);
    });
  });
}
