import 'package:stellar_pos/core/models/product.dart';

/// Converts legacy map-shaped product data into the domain model.
///
/// This adapter exists for older presentation widgets that still consume
/// ProductProvider.productMaps. New code should work with [Product] directly.
class ProductMapMapper {
  const ProductMapMapper._();

  static Product fromMap(Map<String, dynamic> product) {
    return Product(
      id: _string(product['id']),
      name: _string(product['name']),
      unit: _string(product['unit']),
      category: _string(product['category']),
      brand: _string(product['brand']),
      department: _string(product['department']),
      cost: _double(product['cost']),
      price: _double(product['price']),
      stock: _int(product['stock']),
      minStock: _int(product['minStock'], fallback: 5),
      maxStock: _int(product['maxStock'], fallback: 40),
      barcode: _string(product['barcode']),
      hasGroupPricing: _bool(product['hasGroupPricing']),
      groupQuantity: _int(product['groupQuantity']),
      groupPrice: _double(product['groupPrice']),
    );
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static int _int(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _double(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? fallback;
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'si' || text == 'sí';
  }
}
