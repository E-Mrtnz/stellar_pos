import 'package:stellar_pos/core/models/product.dart';

/// Pure inventory rules. It deliberately knows nothing about Flutter state or
/// persistence, so the same rules can be reused by local storage and cloud
/// synchronization later.
class InventoryStockService {
  const InventoryStockService();

  Product decrease(Product product, int quantity) {
    _validateQuantity(quantity);
    return product.copyWith(
      stock: product.stock - quantity,
      touchMetadata: true,
    );
  }

  Product increase(Product product, int quantity) {
    _validateQuantity(quantity);
    return product.copyWith(
      stock: product.stock + quantity,
      touchMetadata: true,
    );
  }

  int adjustmentToPhysical(Product product, int physicalStock) {
    if (physicalStock < 0) {
      throw ArgumentError.value(
        physicalStock,
        'physicalStock',
        'No puede ser negativo.',
      );
    }
    return physicalStock - product.stock;
  }

  Product adjustToPhysical(Product product, int physicalStock) {
    final adjustment = adjustmentToPhysical(product, physicalStock);
    if (adjustment == 0) return product;
    return product.copyWith(
      stock: product.stock + adjustment,
      touchMetadata: true,
    );
  }

  bool canSell(Product product, int quantity) {
    return quantity > 0 && product.stock >= quantity;
  }

  bool isLowStock(Product product) => product.stock <= product.minStock;

  bool isOverstocked(Product product) => product.stock >= product.maxStock;

  void _validateQuantity(int quantity) {
    if (quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Debe ser mayor que cero.',
      );
    }
  }
}
