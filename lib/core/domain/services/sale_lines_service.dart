import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/services/domain/product_pricing_service.dart';

/// Pure construction rules for sale lines.
///
/// Electronic-balance cart DTOs intentionally remain outside this service for
/// now because they belong to the sales/application boundary, not the domain
/// model itself.
class SaleLinesService {
  const SaleLinesService({this.pricing = const ProductPricingService()});

  final ProductPricingService pricing;

  SaleItemRecord physicalItem(Product product, int quantity) {
    if (!pricing.canPrice(product, quantity)) {
      throw ArgumentError('La cantidad del producto debe ser mayor que cero.');
    }

    final lineSubtotal = pricing.lineSubtotal(product, quantity);
    return SaleItemRecord(
      productId: product.id,
      productName: product.name,
      unit: product.unit,
      brand: product.brand,
      barcode: product.barcode,
      cost: product.cost,
      // Keep the real product unit price fixed. Group pricing belongs to the
      // line subtotal, never to the product's stored unit price.
      unitPrice: product.price,
      quantity: quantity,
      lineSubtotal: lineSubtotal,
      discount: 0,
      lineTotal: lineSubtotal,
      imageData: product.imageData,
      hasGroupPricing: product.hasGroupPricing && product.groupQuantity > 0,
    );
  }

  SaleItemRecord applyDiscount(SaleItemRecord item, double discount) {
    final safeDiscount = discount.clamp(0, item.lineSubtotal).toDouble();
    return SaleItemRecord(
      id: item.id,
      productId: item.productId,
      productName: item.productName,
      unit: item.unit,
      brand: item.brand,
      barcode: item.barcode,
      cost: item.cost,
      unitPrice: item.unitPrice,
      quantity: item.quantity,
      lineSubtotal: item.lineSubtotal,
      discount: safeDiscount,
      lineTotal: item.lineSubtotal - safeDiscount,
      imageData: item.imageData,
      isElectronicBalance: item.isElectronicBalance,
      hasGroupPricing: item.hasGroupPricing,
      electronicBalanceAccountId: item.electronicBalanceAccountId,
      electronicBalanceCategory: item.electronicBalanceCategory,
      metadata: item.metadata,
    );
  }
}
