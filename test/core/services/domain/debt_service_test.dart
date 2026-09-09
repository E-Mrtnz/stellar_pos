import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/domain/services/debt_service.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';

void main() {
  const service = DebtService();

  SaleRecord sale({required String id, required String clientId, double total = 10}) =>
      SaleRecord(
        id: id,
        ticketNumber: id,
        createdAt: DateTime(2026, 1, 1),
        clientId: clientId,
        clientName: 'Cliente',
        paymentMethod: 'Fiado',
        items: const [],
        subtotal: total,
        discountPercent: 0,
        discountAmount: 0,
        cardFeeAmount: 0,
        total: total,
        received: 0,
        change: 0,
      );

  test('calculates debt and payment totals', () {
    final sales = [sale(id: 's1', clientId: 'c1'), sale(id: 's2', clientId: 'c1', total: 5)];
    final payments = [
      DebtMovement(
        id: 'p1',
        clientId: 'c1',
        clientName: 'Cliente',
        type: DebtMovementType.payment,
        amount: 4,
        createdAt: DateTime(2026, 1, 2),
      ),
    ];

    expect(service.totalDebt(sales), 15);
    expect(service.totalPaid(payments), 4);
    expect(service.paidForClient('c1', payments), 4);
    expect(service.accountFor('c1', sales, payments)?.remaining, 11);
  });

  test('caps payment at remaining balance or requested limit', () {
    expect(service.appliedPayment(amount: 20, remaining: 12), 12);
    expect(service.appliedPayment(amount: 20, remaining: 12, maxAmount: 5), 5);
    expect(service.appliedPayment(amount: 0, remaining: 12), 0);
  });
}
