import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/domain/services/purchase_report_service.dart';
import 'package:stellar_pos/core/services/domain/purchase_totals_service.dart';
import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/models/sale.dart';

/// Presentation state coordinator for purchase records.
/// Report calculations are delegated to [PurchaseReportService].
class PurchasesProvider extends ChangeNotifier {
  PurchasesProvider({
    PurchaseTotalsService? service,
    PurchaseReportService? reportService,
  })  : _service = service ?? AppDependencies.purchaseTotals,
        _reportService = reportService ?? AppDependencies.purchaseReport;

  final PurchaseTotalsService _service;
  final PurchaseReportService _reportService;
  final List<PurchaseRecord> _purchases = [];

  List<PurchaseRecord> get purchases => List.unmodifiable(_purchases);

  double totalFor(Iterable<PurchaseRecord> records) =>
      _service.totalForPurchases(records);

  double purchasesTotal(Iterable<PurchaseRecord> records) =>
      _reportService.purchasesTotal(records);

  int purchaseCount(Iterable<PurchaseRecord> records) =>
      _reportService.purchaseCount(records);

  int purchasedItemCount(Iterable<PurchaseRecord> records) =>
      _reportService.purchasedItemCount(records);

  int supplierCount(Iterable<PurchaseRecord> records) =>
      _reportService.supplierCount(records);

  double salesTotal(Iterable<SaleRecord> records) =>
      _reportService.salesTotal(records);

  double grossProfit(Iterable<SaleRecord> records) =>
      _reportService.grossProfit(records);

  void addPurchase(PurchaseRecord purchase) {
    _purchases.add(purchase);
    notifyListeners();
  }

  void removePurchase(String id) {
    final before = _purchases.length;
    _purchases.removeWhere((purchase) => purchase.id == id);
    if (_purchases.length != before) notifyListeners();
  }

  void clearPurchases() {
    if (_purchases.isEmpty) return;
    _purchases.clear();
    notifyListeners();
  }
}
