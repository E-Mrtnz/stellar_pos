import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/domain/services/electronic_balance_service.dart';
import 'package:stellar_pos/core/services/domain/product_pricing_service.dart';

class SaleLinesService {
  const SaleLinesService({
    this.pricing = const ProductPricingService(),
    this.balance = const ElectronicBalanceService(),
  });

  final ProductPricingService pricing;
  final ElectronicBalanceService balance;

  SaleItemRecord physicalItem(Product product, int quantity) {
    if (quantity <= 0) {
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
      unitPrice: product.price,
      quantity: quantity,
      lineSubtotal: lineSubtotal,
      discount: 0,
      lineTotal: lineSubtotal,
      imageData: product.imageData,
      hasGroupPricing: product.hasGroupPricing && product.groupQuantity > 0,
    );
  }

  SaleItemRecord electronicItem({
    required ElectronicBalanceAccount account,
    required ElectronicBalanceSale sale,
  }) {
    if (sale.quantity <= 0 || sale.amount <= 0 ||
        !balance.supportsAmount(account, sale.category, sale.amount)) {
      throw ArgumentError('La recarga no es válida o ya no está configurada.');
    }
    final subtotal = sale.amount * sale.quantity;
    return SaleItemRecord(
      productId: 'electronic:${account.id}:${sale.category}:${sale.amount.toStringAsFixed(4)}',
      productName: '${account.companyName} · ${sale.category}',
      unit: sale.category,
      barcode: '',
      cost: balance.providerCost(amount: sale.amount, commissionRate: account.commissionRate),
      unitPrice: sale.amount,
      quantity: sale.quantity,
      lineSubtotal: subtotal,
      discount: 0,
      lineTotal: subtotal,
      isElectronicBalance: true,
      electronicBalanceAccountId: account.id,
      electronicBalanceCategory: sale.category,
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
