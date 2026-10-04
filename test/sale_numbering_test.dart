import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/models/sale.dart';

void main() {
  test('new local sale can remain without a cloud sale number', () {
    final sale = SaleRecord(
      id: 'device-sale-1',
      ticketNumber: '',
      saleNumber: null,
      createdAt: DateTime(2026, 10, 3),
      clientId: null,
      clientName: '',
      paymentMethod: 'Efectivo',
      items: const [],
      subtotal: 0,
      discountPercent: 0,
      discountAmount: 0,
      cardFeeAmount: 0,
      total: 0,
      received: 0,
      change: 0,
    );

    expect(sale.saleId, 'device-sale-1');
    expect(sale.saleNumber, isNull);
    expect(sale.toMap()['saleNumber'], isNull);
  });

  test('legacy sale keeps its existing ticket number as sale number', () {
    final sale = SaleRecord.fromMap({
      'id': 'legacy-sale-1',
      'ticketNumber': '300',
      'createdAt': '2026-10-03T10:00:00.000',
      'clientName': '',
      'paymentMethod': 'Efectivo',
      'items': <dynamic>[],
      'subtotal': 0,
      'discountPercent': 0,
      'discountAmount': 0,
      'cardFeeAmount': 0,
      'total': 0,
      'received': 0,
      'change': 0,
    });

    expect(sale.ticketNumber, '300');
    expect(sale.saleNumber, '300');
  });

  test('explicit cloud sale number survives serialization', () {
    final sale = SaleRecord(
      id: 'cloud-sale-1',
      ticketNumber: '',
      saleNumber: '301',
      createdAt: DateTime(2026, 10, 3),
      clientId: null,
      clientName: '',
      paymentMethod: 'Efectivo',
      items: const [],
      subtotal: 0,
      discountPercent: 0,
      discountAmount: 0,
      cardFeeAmount: 0,
      total: 0,
      received: 0,
      change: 0,
    );

    final restored = SaleRecord.fromMap(sale.toMap());

    expect(restored.saleNumber, '301');
    expect(restored.saleId, 'cloud-sale-1');
  });
}
