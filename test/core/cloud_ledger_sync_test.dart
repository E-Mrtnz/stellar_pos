import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_ledger_sync.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';

class _MemoryCursorStorage implements CloudSyncCursorStorage {
  final Map<String, Object?> valuesByKey = <String, Object?>{};
  @override
  Object? get(String key) => valuesByKey[key];
  @override
  Future<void> put(String key, Object value) async => valuesByKey[key] = value;
  @override
  Future<void> flush() async {}
}

class _FakeLedgerGateway implements CloudLedgerGateway {
  _FakeLedgerGateway(this.page);
  CloudLedgerPullPage page;
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
  }) async => page;
}

class _FakeLedgerApplier implements CloudLedgerRemoteApplier {
  bool fail = false;
  final List<String> applied = <String>[];
  @override
  Future<void> apply(CloudLedgerChange change) async {
    if (fail) throw StateError('simulated local persistence failure');
    applied.add(change.eventId);
  }
}

void main() {
  group('CloudLedgerAcceptance', () {
    test('accepts applied and duplicate receipts only for the expected ID', () {
      final applied = CloudLedgerAcceptance.fromResponse(
        <String, dynamic>{
          'entityType': 'inventoryMovement',
              'operation': 'append',
          'entityId': 'movement-1',
          'status': 'applied',
          'version': 1,
        },
        expectedType: CloudLedgerEntityType.inventoryMovement,
        expectedId: 'movement-1',
      );
      expect(applied.duplicate, isFalse);
      expect(applied.version, 1);

      final duplicate = CloudLedgerAcceptance.fromResponse(
        <String, dynamic>{
          'entityType': 'inventoryMovement',
              'operation': 'append',
          'entityId': 'movement-1',
          'status': 'duplicate',
          'version': 1,
        },
        expectedType: CloudLedgerEntityType.inventoryMovement,
        expectedId: 'movement-1',
      );
      expect(duplicate.duplicate, isTrue);
      expect(
        () => CloudLedgerAcceptance.fromResponse(
          <String, dynamic>{
            'entityType': 'purchase',
            'entityId': 'movement-1',
            'status': 'applied',
            'version': 1,
          },
          expectedType: CloudLedgerEntityType.inventoryMovement,
          expectedId: 'movement-1',
        ),
        throwsFormatException,
      );
    });
  });

  group('CloudLedgerPullPage', () {
    test('validates store, ordered versions and cursor before returning page', () {
      final page = CloudLedgerPullPage.fromResponse(
        <String, dynamic>{
          'storeId': 'store-a',
          'afterVersion': 4,
          'nextCursor': 6,
          'hasMore': false,
          'changes': <Map<String, dynamic>>[
            <String, dynamic>{
              'storeId': 'store-a',
              'eventId': 'inventoryMovement_move-5',
              'entityType': 'inventoryMovement',
              'operation': 'append',
              'entityId': 'move-5',
              'operation': 'append',
              'version': 5,
              'payload': <String, dynamic>{'id': 'move-5', 'quantityDelta': -2},
            },
            <String, dynamic>{
              'storeId': 'store-a',
              'eventId': 'debtMovement_debt-6',
              'entityType': 'debtMovement',
              'operation': 'append',
              'entityId': 'debt-6',
              'operation': 'append',
              'version': 6,
              'payload': <String, dynamic>{'id': 'debt-6', 'amount': 10},
            },
          ],
        },
        expectedStoreId: 'store-a',
        expectedCursor: 4,
      );
      expect(page.nextCursor, 6);
      expect(page.changes, hasLength(2));
    });

    test('rejects cross-store changes, nonmonotonic versions and wrong cursors', () {
      Map<String, dynamic> response({
        String store = 'store-a',
        int next = 5,
        List<Map<String, dynamic>>? changes,
      }) => <String, dynamic>{
        'storeId': store,
        'afterVersion': 4,
        'nextCursor': next,
        'hasMore': false,
        'changes': changes ?? <Map<String, dynamic>>[
          <String, dynamic>{
            'storeId': 'store-a',
            'eventId': 'inventoryMovement_move-5',
            'entityType': 'inventoryMovement',
              'operation': 'append',
            'entityId': 'move-5',
            'version': 5,
            'payload': <String, dynamic>{'id': 'move-5'},
          },
        ],
      };

      expect(
        () => CloudLedgerPullPage.fromResponse(
          response(store: 'store-b'),
          expectedStoreId: 'store-a',
          expectedCursor: 4,
        ),
        throwsFormatException,
      );
      expect(
        () => CloudLedgerPullPage.fromResponse(
          response(next: 4),
          expectedStoreId: 'store-a',
          expectedCursor: 4,
        ),
        throwsFormatException,
      );
      expect(
        () => CloudLedgerPullPage.fromResponse(
          response(changes: <Map<String, dynamic>>[
            <String, dynamic>{
              'storeId': 'store-a', 'eventId': 'a',
              'entityType': 'inventoryMovement', 'operation': 'append', 'entityId': 'move-a',
              'version': 6, 'payload': <String, dynamic>{'id': 'move-a'},
            },
            <String, dynamic>{
              'storeId': 'store-a', 'eventId': 'b',
              'entityType': 'inventoryMovement', 'operation': 'append', 'entityId': 'move-b',
              'version': 5, 'payload': <String, dynamic>{'id': 'move-b'},
            },
          ], next: 5),
          expectedStoreId: 'store-a',
          expectedCursor: 4,
        ),
        throwsFormatException,
      );
    });
  });

  group('CloudLedgerPullCoordinator', () {
    test('advances cursor only after the full page is applied', () async {
      final storage = _MemoryCursorStorage();
      final cursors = CloudSyncCursorStore(storage: storage);
      final page = CloudLedgerPullPage(
        storeId: 'store-a',
        afterVersion: 0,
        nextCursor: 1,
        hasMore: false,
        changes: <CloudLedgerChange>[
          CloudLedgerChange(
            storeId: 'store-a',
            eventId: 'inventoryMovement_move-1',
            entityType: CloudLedgerEntityType.inventoryMovement,
            entityId: 'move-1',
            version: 1,
            payload: <String, dynamic>{'id': 'move-1', 'quantityDelta': 3},
          ),
        ],
      );
      final gateway = _FakeLedgerGateway(page);
      final applier = _FakeLedgerApplier()..fail = true;
      final coordinator = CloudLedgerPullCoordinator(
        gateway: gateway, applier: applier, cursors: cursors,
      );
      await expectLater(
        coordinator.pullOnce(storeId: 'store-a', deviceId: 'device-a'),
        throwsStateError,
      );
      expect(await cursors.read(storeId: 'store-a', deviceId: 'device-a'), isNull);

      applier.fail = false;
      await coordinator.pullOnce(storeId: 'store-a', deviceId: 'device-a');
      expect(applier.applied, <String>['inventoryMovement_move-1']);
      expect(
        (await cursors.read(storeId: 'store-a', deviceId: 'device-a'))?.version,
        1,
      );
    });
  });

}
