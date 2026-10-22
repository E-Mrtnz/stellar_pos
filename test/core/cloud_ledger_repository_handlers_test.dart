import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_ledger_repository_handlers.dart';
import 'package:stellar_pos/core/cloud_ledger_sync.dart';

class _MemoryProjectionStorage implements CloudLedgerProjectionStorage {
  final Map<String, Object?> values = <String, Object?>{};
  int flushCount = 0;

  @override
  Future<Object?> get(String entityId) async => values[entityId];

  @override
  Future<void> put(String entityId, Map<String, dynamic> payload) async {
    values[entityId] = Map<String, dynamic>.from(payload);
  }

  @override
  Future<void> flush() async {
    flushCount++;
  }
}

CloudLedgerChange _change({
  String storeId = 'store-a',
  String entityId = 'purchase-1',
  Map<String, dynamic>? payload,
  CloudLedgerEntityType type = CloudLedgerEntityType.purchase,
}) =>
    CloudLedgerChange(
      storeId: storeId,
      eventId: '${type.name}_${entityId}',
      entityType: type,
      entityId: entityId,
      version: 1,
      payload: payload ??
          <String, dynamic>{
            'id': entityId,
            'total': 12.5,
            'metadata': <String, dynamic>{'currency': 'USD', 'source': 'local'},
          },
    );

void main() {
  group('CloudLedgerRepositoryHandlers', () {
    late Map<String, _MemoryProjectionStorage> boxes;
    late CloudLedgerRepositoryHandlers repositoryHandlers;

    setUp(() {
      boxes = <String, _MemoryProjectionStorage>{};
      repositoryHandlers = CloudLedgerRepositoryHandlers(
        storageFactory: (boxName) async =>
            boxes.putIfAbsent(boxName, _MemoryProjectionStorage.new),
      );
    });

    test('writes and flushes a projection before returning', () async {
      final change = _change();

      await repositoryHandlers.handlers[change.entityType]!(change);

      final storage = boxes['cloud_ledger_projection_purchase_store-a']!;
      expect(storage.values['purchase-1'], change.payload);
      expect(storage.flushCount, 1);
    });

    test('treats identical replay as a no-op even if map key order differs',
        () async {
      final first = _change(
        payload: <String, dynamic>{
          'id': 'purchase-1',
          'total': 12.5,
          'metadata': <String, dynamic>{'currency': 'USD', 'source': 'local'},
        },
      );
      final replay = _change(
        payload: <String, dynamic>{
          'metadata': <String, dynamic>{'source': 'local', 'currency': 'USD'},
          'total': 12.5,
          'id': 'purchase-1',
        },
      );
      final handler = repositoryHandlers.handlers[first.entityType]!;

      await handler(first);
      await handler(replay);

      expect(boxes.values.single.values, hasLength(1));
      expect(boxes.values.single.flushCount, 1);
    });

    test('rejects reusing an entity ID with different payload', () async {
      final first = _change();
      final conflicting = _change(
        payload: <String, dynamic>{'id': 'purchase-1', 'total': 99.0},
      );
      final handler = repositoryHandlers.handlers[first.entityType]!;

      await handler(first);
      await expectLater(handler(conflicting), throwsStateError);
      expect(boxes.values.single.flushCount, 1);
    });

    test('isolates identical entity IDs in different stores', () async {
      final handler = repositoryHandlers.handlers[CloudLedgerEntityType.purchase]!;
      await handler(_change(storeId: 'store-a'));
      await handler(_change(storeId: 'store-b'));

      expect(boxes, hasLength(2));
      expect(
        boxes['cloud_ledger_projection_purchase_store-a']!.values,
        contains('purchase-1'),
      );
      expect(
        boxes['cloud_ledger_projection_purchase_store-b']!.values,
        contains('purchase-1'),
      );
    });

    test('rejects invalid store and entity identifiers', () async {
      final handler = repositoryHandlers.handlers[CloudLedgerEntityType.purchase]!;
      await expectLater(
        handler(_change(storeId: 'store/a')),
        throwsFormatException,
      );
      await expectLater(
        handler(_change(entityId: 'purchase/1')),
        throwsFormatException,
      );
      expect(boxes, isEmpty);
    });
  });
}
