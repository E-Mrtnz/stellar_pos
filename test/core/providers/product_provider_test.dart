import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/models/product.dart';

void main() {
  test('registers a product brand through the injected catalog contract', () {
    final catalog = CatalogProvider();
    final products = ProductProvider(catalogRegistrar: catalog);

    products.addProduct(
      Product(
        id: 'product-1',
        name: 'Coca-Cola',
        unit: '354 ml',
        category: 'Bebidas',
        brand: 'Coca-Cola',
        distributor: 'Distribuidora',
        cost: 0.50,
        price: 0.75,
        stock: 10,
        minStock: 2,
        maxStock: 20,
        barcode: '123456',
      ),
    );

    expect(catalog.brands, contains('Coca-Cola'));
  });
}
