import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_inventory_movement.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';

void main() {
  final occurredAt = DateTime.utc(2026, 10, 20, 12);

  CloudInventoryMovement movement({
    String movementId = 'movement-1',
    String storeId = 'store-a',
    String productId = 'product-1',
    int delta = -3,
    String reason = 'sale',
    int localVersion = 1,
  }) => CloudInventoryMovement(
    movementId: movementId,
    storeId: storeId,
    productId: productId,
    delta: delta,
    reason: reason,
    occurredAt: occurredAt,
    localVersion: localVersion,
  );

  test('serializes a movement with stable idempotency identity', () {
    final value = movement();
    expect(value.validate(activeStoreId: 'store-a'), isNull);
    expect(value.toPayload(), <String, Object?>{
      'movementId': 'movement-1',
      'productId': 'product-1',
      'delta': -3,
      'reason': 'sale',
      'occurredAt': occurredAt.toIso8601String(),
      'localVersion': 1,
    });
  });

  test('round trips a payload while taking store identity from envelope', () {
    final original = movement();
    final restored = CloudInventoryMovement.fromPayload(
      Map<String, dynamic>.from(original.toPayload()),
      storeId: 'store-a',
    );

    expect(restored.movementId, original.movementId);
    expect(restored.storeId, 'store-a');
    expect(restored.productId, original.productId);
    expect(restored.delta, original.delta);
    expect(restored.reason, original.reason);
    expect(restored.occurredAt, original.occurredAt);
    expect(restored.localVersion, original.localVersion);
  });

  test('rejects a movement for a different active store', () {
    expect(movement().validate(activeStoreId: 'store-b'), 'store-mismatch');
  });

  test('rejects invalid identity, zero delta, missing reason and version', () {
    expect(movement(movementId: 'bad/id').validate(activeStoreId: 'store-a'),
        'invalid-movement-id');
    expect(movement(movementId: 'id with spaces').validate(activeStoreId: 'store-a'),
        'invalid-movement-id');
    expect(movement(storeId: 'store/invalid').validate(activeStoreId: 'store/invalid'),
        'invalid-store-id');
    expect(movement(productId: 'product.invalid').validate(activeStoreId: 'store-a'),
        'invalid-product-id');
    expect(movement(productId: ' ').validate(activeStoreId: 'store-a'),
        'invalid-product-id');
    expect(movement(delta: 0).validate(activeStoreId: 'store-a'), 'zero-delta');
    expect(movement(reason: ' ').validate(activeStoreId: 'store-a'),
        'missing-reason');
    expect(movement(reason: ' sale ').validate(activeStoreId: 'store-a'),
        'reason-not-normalized');
    expect(movement(localVersion: -1).validate(activeStoreId: 'store-a'),
        'invalid-local-version');
    expect(movement(localVersion: 0).validate(activeStoreId: 'store-a'),
        'invalid-local-version');
  });


  test('creates a stable outbox envelope without enabling transport', () {
    final value = movement();
    final event = value.toSyncEvent();

    expect(event.eventId, 'inventory-movement-movement-1');
    expect(event.storeId, 'store-a');
    expect(event.entityType, 'inventoryMovement');
    expect(event.entityId, 'movement-1');
    expect(event.operation, CloudSyncOperation.create);
    expect(event.localVersion, 1);
    expect(event.payload, value.toPayload());
    expect(event.status, CloudSyncEventStatus.pending);
  });

  test('does not create an envelope for an invalid movement', () {
    expect(
      () => movement(delta: 0).toSyncEvent(),
      throwsArgumentError,
    );
  });

  test('rejects malformed serialized payloads', () {
    expect(
      () => CloudInventoryMovement.fromPayload(
        <String, dynamic>{'movementId': 'movement-1'},
        storeId: 'store-a',
      ),
      throwsFormatException,
    );
  });

  test('rejects unknown fields in serialized payloads', () {
    final payload = Map<String, dynamic>.from(movement().toPayload())
      ..['unexpected'] = true;

    expect(
      () => CloudInventoryMovement.fromPayload(payload, storeId: 'store-a'),
      throwsFormatException,
    );
  });
}
