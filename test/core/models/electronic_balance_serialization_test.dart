import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/models/electronic_balance.dart';

void main() {
  test('ElectronicBalanceAccount preserves nested sale options', () {
    final account = ElectronicBalanceAccount(
      id: 'account-1',
      companyName: 'Proveedor',
      commissionRate: 5,
      balance: 100,
      saleOptions: [
        ElectronicBalanceSaleOption(
          id: 'option-1',
          category: 'Recarga',
          amount: 10,
        ),
      ],
    );

    final restored = ElectronicBalanceAccount.fromMap(account.toMap());

    expect(restored.id, account.id);
    expect(restored.companyName, account.companyName);
    expect(restored.commissionRate, 5);
    expect(restored.balance, 100);
    expect(restored.saleOptions, hasLength(1));
    expect(restored.saleOptions.single.id, 'option-1');
    expect(restored.saleOptions.single.amount, 10);
  });
}
