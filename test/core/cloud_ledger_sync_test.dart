import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_ledger_sync.dart';

void main() {
  group('CloudLedgerAcceptance', () {
    test('accepts applied and duplicate receipts only for the expected ID', () {
      final applied = CloudLedgerAcceptance.fromResponse(
        <String, dynamic>{
          'entityType': 'inventoryMovement',
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
              'entityId': 'move-5',
              'operation': 'append',
              'version': 5,
              'payload': <String, dynamic>{'id': 'move-5', 'quantityDelta': -2},
            },
            <String, dynamic>{
              'storeId': 'store-a',
              'eventId': 'debtMovement_debt-6',
              'entityType': 'debtMovement',
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
              'entityType': 'inventoryMovement', 'entityId': 'move-a',
              'version': 6, 'payload': <String, dynamic>{'id': 'move-a'},
            },
            <String, dynamic>{
              'storeId': 'store-a', 'eventId': 'b',
              'entityType': 'inventoryMovement', 'entityId': 'move-b',
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
}
