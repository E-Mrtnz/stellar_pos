import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/models/debt.dart';

void main() {
  test('DebtMovement preserves type, reference and metadata', () {
    final movement = DebtMovement(
      id: 'movement-1',
      clientId: 'client-1',
      clientName: 'Ana',
      type: DebtMovementType.payment,
      amount: 12.50,
      createdAt: DateTime.utc(2026, 9, 8, 12),
      reference: 'sale-1',
    );

    final restored = DebtMovement.fromMap(movement.toMap());

    expect(restored.id, movement.id);
    expect(restored.clientId, movement.clientId);
    expect(restored.type, DebtMovementType.payment);
    expect(restored.amount, 12.50);
    expect(restored.createdAt, movement.createdAt);
    expect(restored.reference, 'sale-1');
    expect(restored.metadata.createdAt, movement.metadata.createdAt);
  });

  test('DebtAccount preserves totals and derived balance', () {
    final account = DebtAccount(
      clientId: 'client-1',
      clientName: 'Ana',
      totalDebt: 100,
      totalPaid: 35,
    );

    final restored = DebtAccount.fromMap(account.toMap());

    expect(restored.id, 'client-1');
    expect(restored.totalDebt, 100);
    expect(restored.totalPaid, 35);
    expect(restored.remaining, 65);
    expect(restored.paidPercentage, 0.35);
    expect(restored.metadata.version, account.metadata.version);
  });
}
