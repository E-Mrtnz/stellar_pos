import 'package:stellar_pos/core/models/product.dart';

class ProductPricingService {
  const ProductPricingService();

  double lineSubtotal(Product product, int quantity) {
    if (quantity <= 0) return 0;
    if (!product.hasGroupPricing || product.groupQuantity <= 0) {
      return product.price * quantity;
    }
    final groups = quantity ~/ product.groupQuantity;
    final remaining = quantity % product.groupQuantity;
    return groups * product.groupPrice + remaining * product.price;
  }

  double unitProfit(Product product) => product.price - product.cost;

  double unitProfitPercentage(Product product) {
    if (product.cost <= 0) return 0;
    return unitProfit(product) / product.cost * 100;
  }
}
