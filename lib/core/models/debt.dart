enum DebtMovementType { debt, payment }

class DebtMovement {
  final String id;
  final String clientId;
  final String clientName;
  final DebtMovementType type;
  final double amount;
  final DateTime createdAt;
  final String? reference;

  const DebtMovement({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.reference,
  });
}

class DebtAccount {
  final String clientId;
  final String clientName;
  final double totalDebt;
  final double totalPaid;

  const DebtAccount({
    required this.clientId,
    required this.clientName,
    required this.totalDebt,
    required this.totalPaid,
  });

  double get remaining => (totalDebt - totalPaid).clamp(0, double.infinity).toDouble();
  double get paidPercentage => totalDebt <= 0 ? 0 : (totalPaid / totalDebt).clamp(0, 1).toDouble();

  DebtAccount copyWith({
    String? clientId,
    String? clientName,
    double? totalDebt,
    double? totalPaid,
  }) {
    return DebtAccount(
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      totalDebt: totalDebt ?? this.totalDebt,
      totalPaid: totalPaid ?? this.totalPaid,
    );
  }
}
