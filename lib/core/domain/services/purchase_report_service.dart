import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/models/sale.dart';

/// Pure calculations used by purchase/report screens.
/// Keeps aggregation rules out of Flutter widgets.
class PurchaseReportService {
  const PurchaseReportService();

  double purchasesTotal(Iterable<PurchaseRecord> purchases) =>
      purchases.fold(0, (sum, purchase) => sum + purchase.total);

  int purchaseCount(Iterable<PurchaseRecord> purchases) =>
      purchases.length;

  int purchasedItemCount(Iterable<PurchaseRecord> purchases) =>
      purchases.fold(0, (sum, purchase) => sum + purchase.itemCount);

  int supplierCount(Iterable<PurchaseRecord> purchases) =>
      purchases.map((purchase) => purchase.distributorName.trim().toLowerCase()).where((name) => name.isNotEmpty).toSet().length;

  double salesTotal(Iterable<SaleRecord> sales) =>
      sales.fold(0, (sum, sale) => sum + sale.total);

  /// Calculates gross profit from the recorded sale line totals and costs.
  /// This preserves group-pricing discounts because [lineTotal] is the
  /// actual amount charged for the line.
  double grossProfit(Iterable<SaleRecord> sales) => sales.fold(
        0,
        (saleSum, sale) => saleSum + sale.items.fold(
              0,
              (lineSum, item) =>
                  lineSum + item.lineTotal - (item.cost * item.quantity),
            ),
      );
}
