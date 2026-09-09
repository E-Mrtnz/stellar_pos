import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/data/mappers/product_map_mapper.dart';

void main() {
  test('maps legacy product map into Product domain model', () {
    final product = ProductMapMapper.fromMap({
      'id': 'p-1',
      'name': 'Bubbaloo',
      'unit': 'unidad',
      'category': 'Dulces',
      'brand': 'Bubbaloo',
      'department': 'Proveedor',
      'cost': '0.05',
      'price': '0.10',
      'stock': 12,
      'minStock': 3,
      'maxStock': 40,
      'barcode': '123456',
      'hasGroupPricing': 'Sí',
      'groupQuantity': '3',
      'groupPrice': '0.25',
    });

    expect(product.id, 'p-1');
    expect(product.name, 'Bubbaloo');
    expect(product.cost, 0.05);
    expect(product.price, 0.10);
    expect(product.stock, 12);
    expect(product.hasGroupPricing, isTrue);
    expect(product.groupQuantity, 3);
    expect(product.groupPrice, 0.25);
  });

  test('uses legacy stock defaults when values are missing', () {
    final product = ProductMapMapper.fromMap({
      'id': 'p-2',
      'name': 'Producto',
    });

    expect(product.minStock, 5);
    expect(product.maxStock, 40);
  });
}
