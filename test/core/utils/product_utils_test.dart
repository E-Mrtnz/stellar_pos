import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/utils/product_utils.dart';

void main() {
  test('legacy map pricing adapter uses centralized group pricing', () {
    final product = <String, dynamic>{
      'id': 'p1',
      'name': 'Bubbaloo',
      'unit': 'unidad',
      'cost': 0.05,
      'price': 0.10,
      'stock': 10,
      'minStock': 1,
      'maxStock': 20,
      'hasGroupPricing': true,
      'groupQuantity': 3,
      'groupPrice': 0.25,
    };

    expect(ProductUtils.priceForQuantity(product, 5), 0.45);
    expect(ProductUtils.priceForQuantity(product, 6), 0.50);
  });
}
