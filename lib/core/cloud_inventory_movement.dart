import 'package:stellar_pos/core/cloud_sync_protocol.dart';

/// Immutable inventory delta for future conflict-safe cloud synchronization.
///
/// Inventory is represented as movements instead of synchronizing whole stock
/// snapshots: two devices can create independent movements without one
/// overwriting the other's quantity. This contract is intentionally not wired
/// to ProductProvider or the network transport yet.
class CloudInventoryMovement {
  const CloudInventoryMovement({
    required this.movementId,
    required this.storeId,
    required this.productId,
    required this.delta,
    required this.reason,
    required this.occurredAt,
    required this.localVersion,
  });

  /// Stable idempotency key. It must be reused unchanged for retries.
  final String movementId;
  final String storeId;
  final String productId;

  /// Positive adds stock; negative removes stock.
  final int delta;
  final String reason;
  final DateTime occurredAt;
  final int localVersion;

  /// Converts the movement to the durable outbox envelope.
  ///
  /// The stable event ID makes retries idempotent. This only builds the local
  /// envelope; the current worker intentionally blocks this entity type until
  /// a server-side inventory contract and emulator tests are available.
  CloudSyncEvent toSyncEvent() {
    final validationError = validate(activeStoreId: storeId);
    if (validationError != null) {
      throw ArgumentError.value(validationError, 'movement',
          'Movimiento de inventario inválido.');
    }
    return CloudSyncEvent(
      eventId: 'inventory-movement:$movementId',
      storeId: storeId,
      entityType: 'inventoryMovement',
      entityId: movementId,
      operation: CloudSyncOperation.create,
      localVersion: localVersion,
      createdAt: occurredAt,
      payload: toPayload(),
    );
  }

  Map<String, Object?> toPayload() => <String, Object?>{
    'movementId': movementId,
    'productId': productId,
    'delta': delta,
    'reason': reason.trim(),
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'localVersion': localVersion,
  };

  /// Returns a stable validation error code, or null when the movement is valid.
  String? validate({required String activeStoreId}) {
    if (movementId.trim().isEmpty || movementId != movementId.trim() || movementId.contains('/')) {
      return 'invalid-movement-id';
    }
    if (storeId.trim().isEmpty || storeId != storeId.trim() || storeId.contains('/')) {
      return 'invalid-store-id';
    }
    if (storeId != activeStoreId) return 'store-mismatch';
    if (productId.trim().isEmpty || productId != productId.trim() || productId.contains('/')) {
      return 'invalid-product-id';
    }
    if (delta == 0) return 'zero-delta';
    if (reason.trim().isEmpty) return 'missing-reason';
    if (reason != reason.trim()) return 'reason-not-normalized';
    if (localVersion < 1) return 'invalid-local-version';
    return null;
  }

  factory CloudInventoryMovement.fromPayload(
    Map<String, dynamic> payload, {
    required String storeId,
  }) {
    final occurredAt = DateTime.tryParse(
      payload['occurredAt']?.toString() ?? '',
    );
    const expectedKeys = <String>{
      'movementId',
      'productId',
      'delta',
      'reason',
      'occurredAt',
      'localVersion',
    };
    if (payload.keys.toSet().difference(expectedKeys).isNotEmpty ||
        !expectedKeys.every(payload.containsKey) ||
        payload['movementId'] is! String ||
        payload['productId'] is! String ||
        payload['delta'] is! int ||
        payload['reason'] is! String ||
        occurredAt == null ||
        payload['localVersion'] is! int) {
      throw const FormatException('Movimiento de inventario inválido.');
    }
    final movement = CloudInventoryMovement(
      movementId: payload['movementId'] as String,
      storeId: storeId,
      productId: payload['productId'] as String,
      delta: payload['delta'] as int,
      reason: payload['reason'] as String,
      occurredAt: occurredAt,
      localVersion: payload['localVersion'] as int,
    );
    final error = movement.validate(activeStoreId: storeId);
    if (error != null) {
      throw FormatException('Movimiento de inventario inválido: $error.');
    }
    return movement;
  }
}
