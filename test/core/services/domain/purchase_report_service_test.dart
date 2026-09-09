import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/domain/services/purchase_report_service.dart';
import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/models/sale.dart';

void main() {
  const service = PurchaseReportService();

  test('aggregates purchase metrics', () {
    final purchases = [
      PurchaseRecord(
        id: 'p1',
        invoiceNumber: 'A',
        distributorName: 'Proveedor A',
        arrivalAt: DateTime.utc(2026, 9, 8),
        paymentMethod: 'Contado',
        items: [
          PurchaseItemRecord(
            id: 'i1',
            productId: 'prod-1',
            productName: 'Arroz',
            unit: '1 lb',
            barcode: '1',
            unitCost: 1,
            quantity: 4,
            total: 4,
          ),
        ],
        subtotal: 4,
        total: 4,
      ),
      PurchaseRecord(
        id: 'p2',
        invoiceNumber: 'B',
        distributorName: 'Proveedor B',
        arrivalAt: DateTime.utc(2026, 9, 8),
        paymentMethod: 'Contado',
        items: [
          PurchaseItemRecord(
            id: 'i2',
            productId: 'prod-2',
            productName: 'Frijol',
            unit: '1 lb',
            barcode: '2',
            unitCost: 2,
            quantity: 3,
            total: 6,
          ),
        ],
        subtotal: 6,
        total: 6,
      ),
    ];

    expect(service.purchasesTotal(purchases), 10);
    expect(service.purchaseCount(purchases), 2);
    expect(service.purchasedItemCount(purchases), 7);
    expect(service.supplierCount(purchases), 2);
  });

  test('gross profit uses actual grouped line total', () {
    final sale = SaleRecord(
      id: 's1',
      ticketNumber: '#1',
      createdAt: DateTime.utc(2026, 9, 8),
      clientId: null,
      clientName: 'Consumidor final',
      paymentMethod: 'Efectivo',
      items: [
        SaleItemRecord(
          id: 'line-1',
          productId: 'prod-1',
          productName: 'Bubbaloo',
          unit: 'unidad',
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
      received: 0.45,
      change: 0,
    );

    expect(service.salesTotal([sale]), 0.45);
    expect(service.grossProfit([sale]), closeTo(0.20, 0.000001));
  });
}
