import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/data/repositories/purchase_repository.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
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
    Repository<PurchaseRecord>? repository,
  })  : _service = service ?? AppDependencies.purchaseTotals,
        _reportService = reportService ?? AppDependencies.purchaseReport,
        _repository = repository;

  final PurchaseTotalsService _service;
  final PurchaseReportService _reportService;
  final Repository<PurchaseRecord>? _repository;
  final List<PurchaseRecord> _purchases = [];
  Future<void>? _loadFuture;
  bool _loaded = false;

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

  Future<void> load() {
    if (_loaded) return Future.value();
    final existing = _loadFuture;
    if (existing != null) return existing;
    final future = _loadFromRepository();
    _loadFuture = future;
    return future;
  }

  void addPurchase(PurchaseRecord purchase) {
    _purchases.add(purchase);
    notifyListeners();
    _persist(() => _repository?.save(purchase));
  }

  void removePurchase(String id) {
    final before = _purchases.length;
    _purchases.removeWhere((purchase) => purchase.id == id);
    if (_purchases.length == before) return;
    notifyListeners();
    _persist(() => _repository?.delete(id));
  }

  void clearPurchases() {
    if (_purchases.isEmpty) return;
    final ids = _purchases.map((purchase) => purchase.id).toList(growable: false);
    _purchases.clear();
    notifyListeners();
    for (final id in ids) {
      _persist(() => _repository?.delete(id));
    }
  }

  Future<void> _loadFromRepository() async {
    final repository = _repository;
    if (repository == null) {
      _loaded = true;
      return;
    }
    final stored = await repository.getAll();
    final byId = <String, PurchaseRecord>{
      for (final purchase in _purchases) purchase.id: purchase,
    };
    for (final purchase in stored) {
      byId.putIfAbsent(purchase.id, () => purchase);
    }
    _purchases
      ..clear()
      ..addAll(byId.values);
    _loaded = true;
    if (stored.isNotEmpty) notifyListeners();
  }

  void _persist(Future<void>? Function()? operation) {
    final future = operation?.call();
    if (future != null) {
      unawaited(future.catchError((_) {}));
    }
  }
}
