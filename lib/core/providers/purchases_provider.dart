import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/data/repositories/purchase_repository.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/domain/services/purchase_report_service.dart';
import 'package:stellar_pos/core/services/domain/purchase_totals_service.dart';
import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';

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

  double totalFor(Iterable<PurchaseRecord> records) => _service.totalForPurchases(records);
  double purchasesTotal(Iterable<PurchaseRecord> records) => _reportService.purchasesTotal(records);
  int purchaseCount(Iterable<PurchaseRecord> records) => _reportService.purchaseCount(records);
  int purchasedItemCount(Iterable<PurchaseRecord> records) => _reportService.purchasedItemCount(records);
  int supplierCount(Iterable<PurchaseRecord> records) => _reportService.supplierCount(records);
  double salesTotal(Iterable<SaleRecord> records) => _reportService.salesTotal(records);
  double grossProfit(Iterable<SaleRecord> records) => _reportService.grossProfit(records);

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

  Future<bool> updatePurchase(
    PurchaseRecord purchase,
    ProductProvider productProvider,
  ) async {
    final index = _purchases.indexWhere((entry) => entry.id == purchase.id);
    if (index < 0) return false;

    final previous = _purchases[index];
    final oldByProduct = <String, PurchaseItemRecord>{
      for (final item in previous.items) item.productId: item,
    };
    final newByProduct = <String, PurchaseItemRecord>{
      for (final item in purchase.items) item.productId: item,
    };
    final productIds = {...oldByProduct.keys, ...newByProduct.keys};

    for (final productId in productIds) {
      final product = productProvider.findById(productId);
      if (product == null) continue;
      final oldItem = oldByProduct[productId];
      final newItem = newByProduct[productId];
      var stock = product.stock - (oldItem?.totalQuantity ?? 0) + (newItem?.totalQuantity ?? 0);
      var cost = product.cost;
      var price = product.price;

      if (oldItem != null && oldItem.previousCost != null &&
          (cost - oldItem.unitCost).abs() < 0.0001) {
        cost = oldItem.previousCost!;
      }
      if (oldItem != null && oldItem.previousSalePrice != null &&
          (price - oldItem.salePrice).abs() < 0.0001) {
        price = oldItem.previousSalePrice!;
      }

      if (newItem != null && newItem.quantity > 0) {
        if (oldItem != null &&
            (newItem.unitCost - oldItem.unitCost).abs() < 0.0001 &&
            oldItem.previousCost != null) {
          cost = oldItem.unitCost;
        }
        if (oldItem != null &&
            (newItem.salePrice - oldItem.salePrice).abs() < 0.0001 &&
            oldItem.previousSalePrice != null) {
          price = oldItem.salePrice;
        }
      }

      productProvider.updateProduct(
        product.copyWith(stock: stock, cost: cost, price: price),
      );
    }

    _purchases[index] = purchase;
    notifyListeners();
    await _repository?.save(purchase);
    return true;
  }

  Future<bool> deletePurchase(
    PurchaseRecord purchase,
    ProductProvider productProvider,
  ) async {
    for (final item in purchase.items) {
      final product = productProvider.findById(item.productId);
      if (product == null) continue;

      var restoredCost = product.cost;
      var restoredPrice = product.price;
      if (item.previousCost != null && (product.cost - item.unitCost).abs() < 0.0001) {
        restoredCost = item.previousCost!;
      }
      if (item.previousSalePrice != null && (product.price - item.salePrice).abs() < 0.0001) {
        restoredPrice = item.previousSalePrice!;
      }

      productProvider.updateProduct(
        product.copyWith(stock: product.stock - item.totalQuantity, cost: restoredCost, price: restoredPrice),
      );
    }

    final before = _purchases.length;
    _purchases.removeWhere((entry) => entry.id == purchase.id);
    if (_purchases.length == before) return false;

    notifyListeners();
    await _repository?.delete(purchase.id);
    return true;
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
    for (final id in ids) _persist(() => _repository?.delete(id));
  }

  Future<void> _loadFromRepository() async {
    final repository = _repository;
    if (repository == null) {
      _loaded = true;
      return;
    }
    final stored = await repository.getAll();
    final byId = <String, PurchaseRecord>{for (final purchase in _purchases) purchase.id: purchase};
    for (final purchase in stored) byId.putIfAbsent(purchase.id, () => purchase);
    _purchases..clear()..addAll(byId.values);
    _loaded = true;
    if (stored.isNotEmpty) notifyListeners();
  }

  void _persist(Future<void>? Function()? operation) {
    final future = operation?.call();
    if (future != null) unawaited(future.catchError((_) {}));
  }
}
