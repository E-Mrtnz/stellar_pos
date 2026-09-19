import 'package:stellar_pos/core/models/electronic_balance.dart';

class ElectronicBalanceService {
  const ElectronicBalanceService();

  static const validCategoryOrder = <String>[
    'Saldo',
    'Internet',
    'Llamada',
  ];

  static const validCategories = <String>{
    'Saldo',
    'Internet',
    'Llamada',
  };

  bool isValidCategory(String category) => category.trim().isNotEmpty;

  double providerCost({
    required double amount,
    required double commissionRate,
  }) {
    _validate(amount, commissionRate);
    return amount * (1 - commissionRate / 100);
  }

  double profit({
    required double amount,
    required double commissionRate,
  }) {
    _validate(amount, commissionRate);
    return amount * commissionRate / 100;
  }

  bool supportsAmount(
    ElectronicBalanceAccount account,
    String category,
    double amount,
  ) {
    return isValidCategory(category) &&
        amount > 0 &&
        account.amountsForCategory(category).any(
          (configured) => (configured - amount).abs() <= 0.000001,
        );
  }

  double commissionRateFor({
    required ElectronicBalanceAccount account,
    required String category,
    required double amount,
  }) {
    final option = account.saleOptions.where((item) {
      return item.category == category &&
          (item.amount - amount).abs() <= 0.000001;
    }).firstWhere(
      (item) => true,
      orElse: () => ElectronicBalanceSaleOption(
        category: category,
        amount: amount,
      ),
    );
    return option.commissionRate ?? account.commissionRate;
  }

  double providerCostForSale({
    required ElectronicBalanceAccount account,
    required String category,
    required double amount,
  }) {
    return providerCost(
      amount: amount,
      commissionRate: commissionRateFor(
        account: account,
        category: category,
        amount: amount,
      ),
    );
  }

  double profitForSale({
    required ElectronicBalanceAccount account,
    required String category,
    required double amount,
  }) {
    return profit(
      amount: amount,
      commissionRate: commissionRateFor(
        account: account,
        category: category,
        amount: amount,
      ),
    );
  }

  void _validate(double amount, double commissionRate) {
    if (amount < 0 || commissionRate < 0 || commissionRate > 100) {
      throw ArgumentError('Monto o comisión inválidos.');
    }
  }
}
