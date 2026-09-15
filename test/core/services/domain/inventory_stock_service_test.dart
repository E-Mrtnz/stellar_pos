import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/domain/services/inventory_stock_service.dart';
import 'package:stellar_pos/core/models/product.dart';

void main() {
  const service = InventoryStockService();
  Product product(int stock) => Product(
    id: 'p',
    name: 'P',
    unit: 'u',
    department: '',
    cost: 1,
    price: 2,
    stock: stock,
    minStock: 0,
    maxStock: 100,
    category: '',
    barcode: '1',
  );
  test('reconciles negative registered stock with physical count', () {
    final p = product(-3);
    expect(service.adjustmentToPhysical(p, 5), 8);
    expect(service.adjustToPhysical(p, 5).stock, 5);
  });
  test('reconciles a lower physical count', () {
    final p = product(10);
    expect(service.adjustmentToPhysical(p, 7), -3);
    expect(service.adjustToPhysical(p, 7).stock, 7);
  });
}
