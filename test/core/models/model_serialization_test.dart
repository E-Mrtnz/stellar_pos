import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/models/client.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/models/purchase.dart';

void main() {
  group('model serialization', () {
    test('Product preserves core fields and metadata', () {
      final product = Product(
        id: 'p1',
        name: 'Coca-Cola',
        unit: '354 ml',
        department: 'Distribuidora A',
        brand: 'Coca-Cola',
        cost: 0.50,
        price: 0.75,
        stock: 12,
        minStock: 5,
        maxStock: 40,
        category: 'Bebidas',
        barcode: '123456',
        hasGroupPricing: true,
        groupQuantity: 3,
        groupPrice: 2.00,
      );

      final restored = Product.fromMap(product.toMap());

      expect(restored.id, product.id);
      expect(restored.name, product.name);
      expect(restored.unit, product.unit);
      expect(restored.department, product.department);
      expect(restored.price, product.price);
      expect(restored.stock, product.stock);
      expect(restored.hasGroupPricing, isTrue);
      expect(restored.groupQuantity, 3);
      expect(restored.groupPrice, 2.00);
      expect(restored.metadata.version, product.metadata.version);
    });

    test('Client preserves metadata through a map round trip', () {
      final client = Client(id: 'c1', name: 'Ana', phone: '555');

      final restored = Client.fromMap(client.toMap());

      expect(restored.id, client.id);
      expect(restored.name, client.name);
      expect(restored.phone, client.phone);
      expect(restored.metadata.createdAt, client.metadata.createdAt);
      expect(restored.metadata.version, client.metadata.version);
    });

    test('PurchaseRecord restores nested purchase items', () {
      final purchase = PurchaseRecord(
        id: 'purchase-1',
        invoiceNumber: 'F-10',
        distributorName: 'Distribuidora A',
        arrivalAt: DateTime.utc(2026, 9, 8, 10),
        paymentMethod: 'Contado',
        items: [
          PurchaseItemRecord(
            id: 'item-1',
            productId: 'p1',
            productName: 'Arroz',
            unit: '1 lb',
            barcode: '789',
            unitCost: 1.25,
            quantity: 4,
            total: 5.00,
          ),
        ],
        subtotal: 5.00,
        total: 5.00,
      );

      final restored = PurchaseRecord.fromMap(purchase.toMap());

      expect(restored.id, purchase.id);
      expect(restored.arrivalAt, purchase.arrivalAt);
      expect(restored.items, hasLength(1));
      expect(restored.items.single.id, 'item-1');
      expect(restored.items.single.quantity, 4);
      expect(restored.total, 5.00);
    });
  });
}
