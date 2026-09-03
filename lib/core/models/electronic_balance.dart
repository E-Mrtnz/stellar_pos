enum ElectronicBalanceTransactionType { purchase, sale }

class ElectronicBalanceSaleOption {
  final String category;
  final double amount;

  const ElectronicBalanceSaleOption({
    required this.category,
    required this.amount,
  });
}

class ElectronicBalanceAccount {
  final String id;
  final String companyName;
  final double commissionRate;
  final double balance;
  final List<ElectronicBalanceSaleOption> saleOptions;

  const ElectronicBalanceAccount({
    required this.id,
    required this.companyName,
    required this.commissionRate,
    required this.balance,
    this.saleOptions = const [],
  });

  double get commissionMultiplier => commissionRate / 100;

  List<double> amountsForCategory(String category) {
    return saleOptions
        .where((option) => option.category == category)
        .map((option) => option.amount)
        .toList();
  }

  ElectronicBalanceAccount copyWith({
    String? id,
    String? companyName,
    double? commissionRate,
    double? balance,
    List<ElectronicBalanceSaleOption>? saleOptions,
  }) {
    return ElectronicBalanceAccount(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      commissionRate: commissionRate ?? this.commissionRate,
      balance: balance ?? this.balance,
      saleOptions: saleOptions ?? this.saleOptions,
    );
  }
}

class ElectronicBalanceTransaction {
  final String id;
  final String accountId;
  final ElectronicBalanceTransactionType type;
  final double amount;
  final double providerCost;
  final double profit;
  final String category;
  final String description;
  final DateTime createdAt;

  const ElectronicBalanceTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.providerCost,
    required this.profit,
    required this.category,
    required this.description,
    required this.createdAt,
  });
}
