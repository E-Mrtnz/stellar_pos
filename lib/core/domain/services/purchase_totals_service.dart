import 'package:stellar_pos/core/models/purchase.dart';

/// Pure purchase calculations shared by presentation, persistence and sync.
class PurchaseTotalsService {
  const PurchaseTotalsService();

  double itemTotal({required double unitCost, required int quantity}) {
    if (quantity <= 0 || unitCost < 0) return 0;
    return unitCost * quantity;
  }

  double subtotal(Iterable<PurchaseItemRecord> items) =>
      items.fold(0.0, (sum, item) => sum + item.total);

  double total(Iterable<PurchaseItemRecord> items) => subtotal(items);

  double totalForPurchases(Iterable<PurchaseRecord> purchases) =>
      purchases.fold(0.0, (sum, purchase) => sum + purchase.total);
}
