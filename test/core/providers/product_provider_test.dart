import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';

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
        department: 'Distribuidora',
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

  test('preserves the existing product metadata when updating a product', () {
    final products = ProductProvider();
    final original = Product(
      id: 'product-2',
      name: 'Agua',
      unit: '500 ml',
      category: 'Bebidas',
      department: 'Distribuidora',
      cost: 0.25,
      price: 0.50,
      stock: 10,
      minStock: 2,
      maxStock: 20,
      barcode: '654321',
    );

    products.addProduct(original);
    final beforeUpdate = products.findById('product-2')!;

    final updated = beforeUpdate.copyWith(price: 0.60);
    expect(products.updateProduct(updated), isTrue);

    final result = products.findById('product-2')!;
    expect(result.price, 0.60);
    expect(result.metadata.version, beforeUpdate.metadata.version + 1);
    expect(result.metadata.createdAt, beforeUpdate.metadata.createdAt);
    expect(result.metadata.updatedAt.isAfter(beforeUpdate.metadata.updatedAt), isTrue);
  });
}
