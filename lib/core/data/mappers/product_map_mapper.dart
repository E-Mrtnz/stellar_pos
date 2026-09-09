import 'package:stellar_pos/core/models/product.dart';

/// Converts legacy map-shaped product data into the domain model.
///
/// Kept only for compatibility with older presentation code. New code should
/// use [Product.fromMap] directly.
class ProductMapMapper {
  const ProductMapMapper._();

  static Product fromMap(Map<String, dynamic> product) => Product.fromMap(product);
}
