import 'package:stellar_pos/core/models/sync_metadata.dart';

enum DebtMovementType { debt, payment }

class DebtMovement implements SyncableEntity {
  @override
  final String id;
  final String clientId;
  final String clientName;
  final DebtMovementType type;
  final double amount;
  final DateTime createdAt;
  final String? reference;
  @override
  final SyncMetadata metadata;

  DebtMovement({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.reference,
    SyncMetadata? metadata,
  }) : metadata = metadata ??
            SyncMetadata(
              createdAt: createdAt.toUtc(),
              updatedAt: createdAt.toUtc(),
            );

  Map<String, dynamic> toMap() => {
        'id': id,
        'clientId': clientId,
        'clientName': clientName,
        'type': type.name,
        'amount': amount,
        'createdAt': createdAt.toIso8601String(),
        'reference': reference,
        'metadata': metadata.toMap(),
      };
}

class DebtAccount implements SyncableEntity {
  @override
  String get id => clientId;

  final String clientId;
  final String clientName;
  final double totalDebt;
  final double totalPaid;
  @override
  final SyncMetadata metadata;

  DebtAccount({
    required this.clientId,
    required this.clientName,
    required this.totalDebt,
    required this.totalPaid,
    SyncMetadata? metadata,
  }) : metadata = metadata ?? SyncMetadata.initial();

  double get remaining =>
      (totalDebt - totalPaid).clamp(0, double.infinity).toDouble();

  double get paidPercentage =>
      totalDebt <= 0 ? 0 : (totalPaid / totalDebt).clamp(0, 1).toDouble();

  DebtAccount copyWith({
    String? clientId,
    String? clientName,
    double? totalDebt,
    double? totalPaid,
    SyncMetadata? metadata,
    bool touchMetadata = true,
  }) => DebtAccount(
        clientId: clientId ?? this.clientId,
        clientName: clientName ?? this.clientName,
        totalDebt: totalDebt ?? this.totalDebt,
        totalPaid: totalPaid ?? this.totalPaid,
        metadata: metadata ??
            (touchMetadata ? this.metadata.touch() : this.metadata),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'clientId': clientId,
        'clientName': clientName,
        'totalDebt': totalDebt,
        'totalPaid': totalPaid,
        'metadata': metadata.toMap(),
      };
}
