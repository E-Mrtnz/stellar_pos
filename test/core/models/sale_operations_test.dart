import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/models/sale.dart';

SaleItemRecord _item({String id = 'p1', String name = 'Coca Cola', double price = 2.50, int quantity = 1}) => SaleItemRecord(
      id: id,
      productId: id,
      productName: name,
      unit: '354 ml',
      barcode: '',
      cost: 2,
      unitPrice: price,
      quantity: quantity,
      lineSubtotal: price * quantity,
      discount: 0,
      lineTotal: price * quantity,
    );

SaleRecord _sale({List<SaleOperationRecord> operations = const [], SaleStatus status = SaleStatus.completed}) => SaleRecord(
      id: 's1',
      ticketNumber: '00000001',
      createdAt: DateTime.now(),
      clientId: null,
      clientName: 'Consumidor final',
      paymentMethod: 'Efectivo',
      items: [_item()],
      subtotal: 2.50,
      discountPercent: 0,
      discountAmount: 0,
      cardFeeAmount: 0,
      total: 2.50,
      received: 2.50,
      change: 0,
      status: status,
      operations: operations,
    );

void main() {
  test('completed sale keeps its total', () {
    expect(_sale().effectiveTotal, 2.50);
    expect(_sale().isCompleted, isTrue);
  });

  test('partial return reduces effective total without changing original total', () {
    final operation = SaleOperationRecord(
      type: SaleOperationType.returnItem,
      createdAt: DateTime.now(),
      itemsOut: [_item()],
      amountDelta: -2.50,
    );
    final sale = _sale(operations: [operation]);
    expect(sale.total, 2.50);
    expect(sale.effectiveTotal, 0);
    expect(sale.operations.single.label, 'DEVOLUCIÓN');
  });

  test('change can increase or decrease effective total', () {
    final operation = SaleOperationRecord(
      type: SaleOperationType.change,
      createdAt: DateTime.now(),
      itemsOut: [_item(price: 2.50)],
      itemsIn: [_item(id: 'p2', name: 'Coca', price: 1.25)],
      amountDelta: -1.25,
    );
    final sale = _sale(operations: [operation]);
    expect(sale.effectiveTotal, 1.25);
    expect(sale.operations.single.label, 'CAMBIO');
  });

  test('annulled sale has zero effective total and zero effective profit', () {
    final sale = _sale(status: SaleStatus.annulled);
    expect(sale.effectiveTotal, 0);
    expect(sale.effectiveProfit, 0);
  });

  test('status and operations survive serialization', () {
    final operation = SaleOperationRecord(type: SaleOperationType.change, createdAt: DateTime.now(), amountDelta: 1.0);
    final sale = _sale(operations: [operation]);
    final restored = SaleRecord.fromMap(sale.toMap());
    expect(restored.status, SaleStatus.completed);
    expect(restored.operations.single.type, SaleOperationType.change);
    expect(restored.operations.single.amountDelta, 1.0);
  });
}
