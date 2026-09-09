import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/domain/services/electronic_balance_service.dart';

void main() {
  const service = ElectronicBalanceService();

  test('validates configured electronic balance categories', () {
    expect(service.isValidCategory('Saldo'), isTrue);
    expect(service.isValidCategory('Internet'), isTrue);
    expect(service.isValidCategory('Llamada'), isTrue);
    expect(service.isValidCategory('Otro'), isFalse);
  });

  test('keeps a stable category order for presentation', () {
    expect(
      ElectronicBalanceService.validCategoryOrder,
      ['Saldo', 'Internet', 'Llamada'],
    );
  });

  test('calculates provider cost and profit from commission', () {
    expect(service.providerCost(amount: 10, commissionRate: 5), 9.5);
    expect(service.profit(amount: 10, commissionRate: 5), 0.5);
  });
}
