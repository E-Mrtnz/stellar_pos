import 'package:stellar_pos/core/domain/services/catalog_value_service.dart';
import 'package:stellar_pos/core/domain/services/debt_service.dart';
import 'package:stellar_pos/core/domain/services/electronic_balance_service.dart';
import 'package:stellar_pos/core/domain/services/inventory_stock_service.dart';
import 'package:stellar_pos/core/domain/services/purchase_report_service.dart';
import 'package:stellar_pos/core/domain/services/purchase_totals_service.dart';
import 'package:stellar_pos/core/domain/services/sale_lines_service.dart';
import 'package:stellar_pos/core/domain/services/sale_lifecycle_service.dart';
import 'package:stellar_pos/core/domain/services/sale_totals_service.dart';
import 'package:stellar_pos/core/services/domain/product_pricing_service.dart';

/// Shared domain dependencies used by application state coordinators.
///
/// Keeping these factories in one place makes the composition root explicit
/// and gives us a single seam for replacing services when persistent storage
/// and synchronization are introduced later.
class AppDependencies {
  const AppDependencies._();

  static const catalogValue = CatalogValueService();
  static const debt = DebtService();
  static const electronicBalance = ElectronicBalanceService();
  static const inventoryStock = InventoryStockService();
  static const purchaseReport = PurchaseReportService();
  static const purchaseTotals = PurchaseTotalsService();
  static const saleLines = SaleLinesService();
  static const saleLifecycle = SaleLifecycleService();
  static const saleTotals = SaleTotalsService();
  static const productPricing = ProductPricingService();
}
