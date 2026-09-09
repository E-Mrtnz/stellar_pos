import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/services/domain/product_pricing_service.dart';

void main() {
  const service = ProductPricingService();

  Product product({bool groups = true}) => Product(
        id: 'test',
        name: 'Bubbaloo',
        unit: 'Unidad',
        department: 'Snacks',
        cost: 0.05,
        price: 0.10,
        stock: 10,
        minStock: 1,
        maxStock: 20,
        category: 'Snacks',
        barcode: '123',
        hasGroupPricing: groups,
        groupQuantity: groups ? 3 : 0,
        groupPrice: groups ? 0.25 : 0,
      );

  test('applies group price and remaining units', () {
    expect(service.lineSubtotal(product(), 5), closeTo(0.45, 0.000001));
    expect(service.lineSubtotal(product(), 6), closeTo(0.50, 0.000001));
  });

  test('uses regular unit price when group pricing is disabled', () {
    expect(service.lineSubtotal(product(groups: false), 5), closeTo(0.50, 0.000001));
  });

  test('returns zero for invalid quantity', () {
    expect(service.lineSubtotal(product(), 0), 0);
  });
}
