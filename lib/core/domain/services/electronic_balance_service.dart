import 'package:stellar_pos/core/models/electronic_balance.dart';

class ElectronicBalanceService {
  const ElectronicBalanceService();

  static const validCategories = <String>{'Saldo', 'Internet', 'Llamada'};

  bool isValidCategory(String category) => validCategories.contains(category.trim());

  double providerCost({required double amount, required double commissionRate}) {
    if (amount < 0 || commissionRate < 0 || commissionRate > 100) {
      throw ArgumentError('Monto o comisión inválidos.');
    }
    return amount * (1 - commissionRate / 100);
  }

  double profit({required double amount, required double commissionRate}) {
    if (amount < 0 || commissionRate < 0 || commissionRate > 100) {
      throw ArgumentError('Monto o comisión inválidos.');
    }
    return amount * commissionRate / 100;
  }

  bool supportsAmount(ElectronicBalanceAccount account, String category, double amount) {
    return isValidCategory(category) &&
        amount > 0 &&
        account.amountsForCategory(category).any(
          (configured) => (configured - amount).abs() <= 0.000001,
        );
  }
}
