import 'package:stellar_pos/core/cloud_sync_protocol.dart';

/// Immutable inventory delta for conflict-safe cloud ledger synchronization.
///
/// This is an append-only movement contract. It deliberately does not mutate
/// Product.stock directly: local stock application and inbound reconciliation
/// must be coordinated by the inventory domain layer.
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

  final String movementId;
  final String storeId;
  final String productId;

  /// Positive adds stock; negative removes stock.
  final int delta;
  final String reason;
  final DateTime occurredAt;
  final int localVersion;

  /// Builds a durable outbox envelope with a stable idempotency key.
  CloudSyncEvent toSyncEvent() {
    final validationError = validate(activeStoreId: storeId);
    if (validationError != null) {
      throw ArgumentError.value(
        validationError,
        'movement',
        'Movimiento de inventario inválido.',
      );
    }
    return CloudSyncEvent(
      eventId: 'inventory-movement-$movementId',
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
        'reason': reason,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'localVersion': localVersion,
      };

  /// Returns a stable validation error code, or null when valid.
  String? validate({required String activeStoreId}) {
    if (!_isValidIdentifier(movementId, maxLength: 100)) {
      return 'invalid-movement-id';
    }
    if (!_isValidIdentifier(storeId, maxLength: 80)) {
      return 'invalid-store-id';
    }
    if (storeId != activeStoreId) return 'store-mismatch';
    if (!_isValidIdentifier(productId, maxLength: 120)) {
      return 'invalid-product-id';
    }
    if (delta == 0) return 'zero-delta';
    if (delta.abs() > 9007199254740991) return 'delta-out-of-range';
    if (reason.trim().isEmpty) return 'missing-reason';
    if (reason != reason.trim()) return 'reason-not-normalized';
    if (localVersion < 1) return 'invalid-local-version';
    return null;
  }

  static bool _isValidIdentifier(String value, {required int maxLength}) {
    return value.isNotEmpty &&
        value == value.trim() &&
        value.length <= maxLength &&
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
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
