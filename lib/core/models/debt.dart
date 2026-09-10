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
  final bool isInitialPayment;
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
    this.isInitialPayment = false,
    SyncMetadata? metadata,
  }) : metadata =
           metadata ??
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
    'isInitialPayment': isInitialPayment,
    'metadata': metadata.toMap(),
  };

  factory DebtMovement.fromMap(Map<String, dynamic> map) => DebtMovement(
    id: map['id']?.toString() ?? '',
    clientId: map['clientId']?.toString() ?? '',
    clientName: map['clientName']?.toString() ?? '',
    type: _type(map['type']),
    amount: _double(map['amount']),
    createdAt: _date(map['createdAt']),
    reference: map['reference']?.toString(),
    isInitialPayment: _bool(map['isInitialPayment']),
    metadata: _metadata(map['metadata']),
  );

  static bool _bool(dynamic value) => value is bool
      ? value
      : ['true', '1', 'si', 'sí'].contains(value?.toString().toLowerCase());

  static DebtMovementType _type(dynamic value) =>
      DebtMovementType.values.firstWhere(
        (item) => item.name == value?.toString(),
        orElse: () => DebtMovementType.payment,
      );

  static DateTime _date(dynamic value) => value is DateTime
      ? value.toUtc()
      : DateTime.tryParse(value?.toString() ?? '')?.toUtc() ??
            DateTime.now().toUtc();

  static double _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  static SyncMetadata _metadata(dynamic value) => value is Map
      ? SyncMetadata.fromMap(Map<String, dynamic>.from(value))
      : SyncMetadata.initial();
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
    metadata:
        metadata ?? (touchMetadata ? this.metadata.touch() : this.metadata),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'totalDebt': totalDebt,
    'totalPaid': totalPaid,
    'metadata': metadata.toMap(),
  };

  factory DebtAccount.fromMap(Map<String, dynamic> map) => DebtAccount(
    clientId: map['clientId']?.toString() ?? map['id']?.toString() ?? '',
    clientName: map['clientName']?.toString() ?? '',
    totalDebt: _double(map['totalDebt']),
    totalPaid: _double(map['totalPaid']),
    metadata: _metadata(map['metadata']),
  );

  static double _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  static SyncMetadata _metadata(dynamic value) => value is Map
      ? SyncMetadata.fromMap(Map<String, dynamic>.from(value))
      : SyncMetadata.initial();
}
