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

  void _validate(double amount, double commissionRate) {
    if (amount < 0 || commissionRate < 0 || commissionRate > 100) {
      throw ArgumentError('Monto o comisión inválidos.');
    }
  }
}
