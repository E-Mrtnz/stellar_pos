import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/models/sale.dart';

void main() {
  test('SaleRecord preserves nested lines and payment data', () {
    final sale = SaleRecord(
      id: 'sale-1',
      ticketNumber: '#0001',
      createdAt: DateTime.utc(2026, 9, 8, 20, 30),
      clientId: 'client-1',
      clientName: 'Cliente',
      paymentMethod: 'Efectivo',
      items: [
        SaleItemRecord(
          id: 'line-1',
          productId: 'p1',
          productName: 'Bubbaloo',
          unit: 'unidad',
          brand: 'Bubbaloo',
          barcode: '123',
          cost: 0.05,
          unitPrice: 0.10,
          quantity: 5,
          lineSubtotal: 0.45,
          discount: 0,
          lineTotal: 0.45,
          hasGroupPricing: true,
        ),
      ],
      subtotal: 0.45,
      discountPercent: 0,
      discountAmount: 0,
      cardFeeAmount: 0,
      total: 0.45,
      received: 1,
      change: 0.55,
    );

    final restored = SaleRecord.fromMap(sale.toMap());

    expect(restored.id, sale.id);
    expect(restored.ticketNumber, sale.ticketNumber);
    expect(restored.createdAt, sale.createdAt);
    expect(restored.clientId, sale.clientId);
    expect(restored.received, 1);
    expect(restored.change, 0.55);
    expect(restored.items, hasLength(1));
    expect(restored.items.single.id, 'line-1');
    expect(restored.items.single.hasGroupPricing, isTrue);
    expect(restored.items.single.lineSubtotal, 0.45);
    expect(restored.metadata.version, sale.metadata.version);
  });

  test('SaleRecord ticket data keeps grouped line total as displayed price', () {
    final sale = SaleRecord(
      id: 'sale-2',
      ticketNumber: '#0002',
      createdAt: DateTime.utc(2026, 9, 8, 20),
      clientId: null,
      clientName: 'Consumidor final',
      paymentMethod: 'Efectivo',
      items: [
        SaleItemRecord(
          id: 'line-2',
          productId: 'p2',
          productName: 'Bubbaloo',
          unit: 'unidad',
          barcode: '456',
          cost: 0.05,
          unitPrice: 0.10,
          quantity: 5,
          lineSubtotal: 0.45,
          discount: 0,
          lineTotal: 0.45,
          hasGroupPricing: true,
        ),
      ],
      subtotal: 0.45,
      discountPercent: 0,
      discountAmount: 0,
      cardFeeAmount: 0,
      total: 0.45,
      received: 0.45,
      change: 0,
    );

    final ticket = sale.toTicketData();

    expect(ticket.items.single.unitPrice, 0.45);
    expect(ticket.items.single.total, 0.45);
  });
}
