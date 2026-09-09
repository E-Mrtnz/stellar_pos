import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_box_names.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/domain/services/electronic_balance_service.dart';
import 'package:stellar_pos/core/domain/services/inventory_stock_service.dart';
import 'package:stellar_pos/core/domain/services/sale_lifecycle_service.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/models/electronic_balance_sale.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/services/domain/product_pricing_service.dart';
import 'package:stellar_pos/core/services/domain/sale_lines_service.dart';
import 'package:stellar_pos/core/services/domain/sale_totals_service.dart';

class SalesProvider extends ChangeNotifier {
  final List<SaleRecord> _sales = [];
  int _nextTicketNumber = 1;
  bool _loaded = false;
  Future<void>? _loadFuture;

  final ProductPricingService _pricing;
  final SaleLinesService _lines;
  final SaleTotalsService _totals;
  final InventoryStockService _stock;
  final ElectronicBalanceService _electronicBalance;
  final SaleLifecycleService _lifecycle;
  final Repository<SaleRecord>? _repository;

  SalesProvider({
    ProductPricingService? pricing,
    SaleLinesService? lines,
    SaleTotalsService? totals,
    InventoryStockService? stock,
    ElectronicBalanceService? electronicBalance,
    SaleLifecycleService? lifecycle,
    Repository<SaleRecord>? repository,
  })  : _pricing = pricing ?? AppDependencies.productPricing,
        _lines = lines ?? AppDependencies.saleLines,
        _totals = totals ?? AppDependencies.saleTotals,
        _stock = stock ?? AppDependencies.inventoryStock,
        _electronicBalance = electronicBalance ?? AppDependencies.electronicBalance,
        _lifecycle = lifecycle ?? AppDependencies.saleLifecycle,
        _repository = repository ?? HiveRepository<SaleRecord>(
          HiveDataSource<SaleRecord>(
            boxName: StorageBoxNames.sales,
            fromMap: SaleRecord.fromMap,
          ),
        );

  List<SaleRecord> get sales => List.unmodifiable(_sales);
  SaleRecord? get latestSale => _sales.isEmpty ? null : _sales.last;
  String get nextTicketNumberPreview => _nextTicketNumber.toString().padLeft(8, '0');

  Future<void> load() {
    if (_loaded) return Future.value();
    final existing = _loadFuture;
    if (existing != null) return existing;
    final future = _loadFromRepository();
    _loadFuture = future;
    return future;
  }

  // Existing sale creation/edit/delete behavior remains unchanged; persistence
  // is intentionally coordinated here after the in-memory state transition.
  SaleRecord createSale({
    required Map<String, int> cartQuantities,
    required ProductProvider productProvider,
    required String paymentMethodLabel,
    required String? clientId,
    required String clientName,
    required double subtotal,
    required double discountPercent,
    required double discountAmount,
    required double cardFeeAmount,
    required double total,
    required double received,
    required double change,
    List<ElectronicBalanceCartSale> electronicSales = const [],
    ElectronicBalanceProvider? electronicBalanceProvider,
  }) {
    if (cartQuantities.isEmpty && electronicSales.isEmpty) throw StateError('No hay productos seleccionados.');
    if (electronicSales.isNotEmpty && electronicBalanceProvider == null) throw StateError('No se pudo acceder al saldo electrónico.');
    final ticketNumber = nextTicketNumberPreview;
    final saleId = _lifecycle.newSaleId();
    final items = <SaleItemRecord>[];
    for (final entry in cartQuantities.entries) {
      final product = productProvider.findById(entry.key);
      if (product == null) throw StateError('Uno de los productos de la venta ya no existe.');
      final quantity = entry.value;
      if (!_pricing.canPrice(product, quantity)) throw StateError('La cantidad de un producto debe ser mayor que cero.');
      final item = _lines.physicalItem(product, quantity);
      final lineDiscount = _totals.proportionalDiscount(lineSubtotal: item.lineSubtotal, subtotal: subtotal, discountAmount: discountAmount);
      items.add(_lines.applyDiscount(item, lineDiscount));
    }
    final balanceProvider = electronicBalanceProvider;
    final balanceAccounts = <String, ElectronicBalanceAccount>{};
    if (balanceProvider != null) {
      for (final electronicSale in electronicSales) {
        final account = balanceProvider.findAccount(electronicSale.accountId);
        if (account == null) throw StateError('La compañía de una recarga ya no existe.');
        if (electronicSale.quantity <= 0 || electronicSale.amount <= 0) throw StateError('La cantidad de una recarga debe ser mayor que cero.');
        if (!_electronicBalance.isValidCategory(electronicSale.category)) throw StateError('El tipo de recarga no es válido.');
        if (!_electronicBalance.supportsAmount(account, electronicSale.category, electronicSale.amount)) throw StateError('El monto de una recarga ya no está configurado para ${account.companyName}.');
        balanceAccounts[electronicSale.accountId] = account;
      }
    }
    for (final electronicSale in electronicSales) {
      final account = balanceAccounts[electronicSale.accountId]!;
      final lineSubtotal = electronicSale.amount * electronicSale.quantity;
      final lineDiscount = _totals.proportionalDiscount(lineSubtotal: lineSubtotal, subtotal: subtotal, discountAmount: discountAmount);
      final providerCost = _electronicBalance.providerCost(amount: electronicSale.amount, commissionRate: account.commissionRate);
      items.add(SaleItemRecord(productId: 'electronic:${electronicSale.accountId}:${electronicSale.category}:${electronicSale.amount.toStringAsFixed(4)}', productName: electronicSale.description, unit: electronicSale.category, barcode: '', quantity: electronicSale.quantity, unitPrice: electronicSale.amount, cost: providerCost, lineSubtotal: lineSubtotal, discount: lineDiscount, lineTotal: lineSubtotal - lineDiscount, isElectronicBalance: true, electronicBalanceAccountId: electronicSale.accountId, electronicBalanceCategory: electronicSale.category));
    }
    final sale = SaleRecord(id: saleId, ticketNumber: ticketNumber, createdAt: DateTime.now(), clientId: clientId, clientName: clientName, paymentMethod: paymentMethodLabel, items: List.unmodifiable(items), subtotal: subtotal, discountPercent: discountPercent, discountAmount: discountAmount, cardFeeAmount: cardFeeAmount, total: total, received: received, change: change);
    for (final entry in cartQuantities.entries) {
      final product = productProvider.findById(entry.key);
      if (product != null) productProvider.updateProduct(_stock.decrease(product, entry.value));
    }
    if (balanceProvider != null && electronicSales.isNotEmpty) {
      for (final entry in electronicSales.map((e) => e.accountId).toSet()) {
        final accountSales = electronicSales.where((sale) => sale.accountId == entry).map((sale) => ElectronicBalanceSale(amount: sale.amount, quantity: sale.quantity, category: sale.category, description: sale.description)).toList(growable: false);
        if (!balanceProvider.registerSales(accountId: entry, sales: accountSales, saleId: sale.id)) throw StateError('No se pudo registrar una de las ventas de saldo.');
      }
    }
    _sales.add(sale);
    _nextTicketNumber++;
    notifyListeners();
    _persist(sale);
    return sale;
  }

  bool deleteSale({required String saleId, required ProductProvider productProvider, ElectronicBalanceProvider? electronicBalanceProvider}) {
    final index = _sales.indexWhere((sale) => sale.id == saleId);
    if (index < 0) return false;
    final sale = _sales[index];
    if (sale.items.any((item) => item.isElectronicBalance)) {
      if (electronicBalanceProvider == null || !electronicBalanceProvider.reverseSale(sale.id)) return false;
    }
    for (final item in sale.items.where((item) => !item.isElectronicBalance)) {
      final product = productProvider.findById(item.productId);
      if (product != null) productProvider.updateProduct(_stock.increase(product, item.quantity));
    }
    _sales.removeAt(index);
    notifyListeners();
    _persistDelete(sale.id);
    return true;
  }

  SaleRecord? findByTicketNumber(String ticketNumber) {
    final normalized = ticketNumber.trim().replaceFirst('#', '');
    if (normalized.isEmpty) return null;
    for (final sale in _sales) if (sale.ticketNumber == normalized) return sale;
    return null;
  }

  void clearSales() {
    if (_sales.isEmpty && _nextTicketNumber == 1) return;
    final ids = _sales.map((sale) => sale.id).toList(growable: false);
    _sales.clear();
    _nextTicketNumber = 1;
    notifyListeners();
    for (final id in ids) _persistDelete(id);
  }

  Future<void> _loadFromRepository() async {
    final repository = _repository;
    if (repository == null) { _loaded = true; return; }
    final stored = await repository.getAll();
    _sales
      ..clear()
      ..addAll(stored..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
    if (_sales.isNotEmpty) {
      final maxTicket = _sales.map((sale) => int.tryParse(sale.ticketNumber) ?? 0).fold<int>(0, (max, value) => value > max ? value : max);
      _nextTicketNumber = maxTicket + 1;
    }
    _loaded = true;
    if (_sales.isNotEmpty) notifyListeners();
  }

  void _persist(SaleRecord sale) { _repository?.save(sale).catchError((_) {}); }
  void _persistDelete(String id) { _repository?.delete(id).catchError((_) {}); }
}

class ElectronicBalanceCartSale {
  final String accountId;
  final String category;
  final double amount;
  final int quantity;
  final String description;
  const ElectronicBalanceCartSale({required this.accountId, required this.category, required this.amount, required this.quantity, required this.description});
}
