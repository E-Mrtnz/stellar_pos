import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/domain/services/inventory_stock_service.dart';
import 'package:stellar_pos/core/models/product.dart';

void main() {
  const service = InventoryStockService();

  Product product({int stock = 10}) => Product(
        id: 'p1',
        name: 'Producto',
        unit: '1 U',
        brand: 'Marca',
        department: 'Abarrotes',
        stock: stock,
        minStock: 5,
        maxStock: 40,
        cost: 0.5,
        price: 1,
        barcode: '123',
      );

  test('decreases and increases stock', () {
    expect(service.decrease(product(), 3).stock, 7);
    expect(service.increase(product(), 3).stock, 13);
  });

  test('does not allow selling more than available stock', () {
    expect(service.canSell(product(stock: 2), 3), isFalse);
    expect(service.canSell(product(stock: 2), 2), isTrue);
  });

  test('detects low and maximum stock', () {
    expect(service.isLowStock(product(stock: 5)), isTrue);
    expect(service.isOverstocked(product(stock: 40)), isTrue);
  });
}
