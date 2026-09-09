import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/data/repositories/sale_repository.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/domain/services/electronic_balance_service.dart';
import 'package:stellar_pos/core/domain/services/inventory_stock_service.dart';
import 'package:stellar_pos/core/domain/services/sale_lifecycle_service.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/models/electronic_balance_sale.dart';
import 'package:stellar_pos/core/models/product.dart';
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
        _repository = repository ?? SaleRepository();

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
    if (cartQuantities.isEmpty && electronicSales.isEmpty) {
      throw StateError('No hay productos seleccionados.');
    }
    if (electronicSales.isNotEmpty && electronicBalanceProvider == null) {
      throw StateError('No se pudo acceder al saldo electrónico.');
    }

    final ticketNumber = nextTicketNumberPreview;
    final saleId = _lifecycle.newSaleId();
    final items = <SaleItemRecord>[];

    for (final entry in cartQuantities.entries) {
      final product = productProvider.findById(entry.key);
      if (product == null) throw StateError('Uno de los productos de la venta ya no existe.');
      final quantity = entry.value;
      if (!_pricing.canPrice(product, quantity)) {
        throw StateError('La cantidad de un producto debe ser mayor que cero.');
      }
      final item = _lines.physicalItem(product, quantity);
      final lineDiscount = _totals.proportionalDiscount(
        lineSubtotal: item.lineSubtotal,
        subtotal: subtotal,
        discountAmount: discountAmount,
      );
      items.add(_lines.applyDiscount(item, lineDiscount));
    }

    final balanceProvider = electronicBalanceProvider;
    final balanceAccounts = <String, ElectronicBalanceAccount>{};
    if (balanceProvider != null) {
      for (final electronicSale in electronicSales) {
        final account = balanceProvider.findAccount(electronicSale.accountId);
        if (account == null) throw StateError('La compañía de una recarga ya no existe.');
        if (electronicSale.quantity <= 0 || electronicSale.amount <= 0) {
          throw StateError('La cantidad de una recarga debe ser mayor que cero.');
        }
        if (!_electronicBalance.isValidCategory(electronicSale.category)) {
          throw StateError('El tipo de recarga no es válido.');
        }
        if (!_electronicBalance.supportsAmount(account, electronicSale.category, electronicSale.amount)) {
          throw StateError('El monto de una recarga ya no está configurado para ${account.companyName}.');
        }
        balanceAccounts[electronicSale.accountId] = account;
      }
    }

    for (final electronicSale in electronicSales) {
      final account = balanceAccounts[electronicSale.accountId]!;
      final lineSubtotal = electronicSale.amount * electronicSale.quantity;
      final lineDiscount = _totals.proportionalDiscount(
        lineSubtotal: lineSubtotal,
        subtotal: subtotal,
        discountAmount: discountAmount,
      );
      final providerCost = _electronicBalance.providerCost(
        amount: electronicSale.amount,
        commissionRate: account.commissionRate,
      );
      items.add(SaleItemRecord(
        productId: 'electronic:${electronicSale.accountId}:${electronicSale.category}:${electronicSale.amount.toStringAsFixed(4)}',
        productName: electronicSale.description,
        unit: electronicSale.category,
        barcode: '',
        quantity: electronicSale.quantity,
        unitPrice: electronicSale.amount,
        cost: providerCost,
        lineSubtotal: lineSubtotal,
        discount: lineDiscount,
        lineTotal: lineSubtotal - lineDiscount,
        isElectronicBalance: true,
        electronicBalanceAccountId: electronicSale.accountId,
        electronicBalanceCategory: electronicSale.category,
      ));
    }

    final sale = SaleRecord(
      id: saleId,
      ticketNumber: ticketNumber,
      createdAt: DateTime.now(),
      clientId: clientId,
      clientName: clientName,
      paymentMethod: paymentMethodLabel,
      items: List.unmodifiable(items),
      subtotal: subtotal,
      discountPercent: discountPercent,
      discountAmount: discountAmount,
      cardFeeAmount: cardFeeAmount,
      total: total,
      received: received,
      change: change,
    );

    for (final entry in cartQuantities.entries) {
      final product = productProvider.findById(entry.key);
      if (product != null) {
        productProvider.updateProduct(_stock.decrease(product, entry.value));
      }
    }

    if (balanceProvider != null && electronicSales.isNotEmpty) {
      for (final accountId in electronicSales.map((e) => e.accountId).toSet()) {
        final accountSales = electronicSales
            .where((sale) => sale.accountId == accountId)
            .map((sale) => ElectronicBalanceSale(
                  amount: sale.amount,
                  quantity: sale.quantity,
                  category: sale.category,
                  description: sale.description,
                ))
            .toList(growable: false);
        if (!balanceProvider.registerSales(
          accountId: accountId,
          sales: accountSales,
          saleId: sale.id,
        )) {
          throw StateError('No se pudo registrar una de las ventas de saldo.');
        }
      }
    }

    _sales.add(sale);
    _nextTicketNumber++;
    notifyListeners();
    _persist(sale);
    return sale;
  }

  SaleRecord updateSale({
    required String saleId,
    required List<SaleItemRecord> updatedItems,
    required ProductProvider productProvider,
    ElectronicBalanceProvider? electronicBalanceProvider,
  }) {
    final index = _sales.indexWhere((sale) => sale.id == saleId);
    if (index < 0) throw StateError('La venta que intentas editar ya no existe.');
    if (updatedItems.isEmpty) throw StateError('La venta debe conservar al menos un producto.');

    final oldSale = _sales[index];
    final oldPhysical = <String, int>{};
    for (final item in oldSale.items) {
      if (!item.isElectronicBalance) oldPhysical[item.productId] = (oldPhysical[item.productId] ?? 0) + item.quantity;
    }
    final newPhysical = <String, int>{};
    for (final item in updatedItems) {
      if (item.isElectronicBalance) continue;
      final product = productProvider.findById(item.productId);
      if (product == null) throw StateError('Uno de los productos seleccionados ya no existe.');
      if (!_pricing.canPrice(product, item.quantity)) throw StateError('La cantidad de un producto debe ser mayor que cero.');
      newPhysical[item.productId] = (newPhysical[item.productId] ?? 0) + item.quantity;
    }

    final hasElectronic = updatedItems.any((item) => item.isElectronicBalance);
    if (hasElectronic && electronicBalanceProvider == null) throw StateError('No se pudo acceder al saldo electrónico.');
    if (hasElectronic) {
      for (final item in updatedItems.where((item) => item.isElectronicBalance)) {
        final accountId = item.electronicBalanceAccountId;
        final category = item.electronicBalanceCategory;
        final account = accountId == null ? null : electronicBalanceProvider!.findAccount(accountId);
        if (account == null || category == null) throw StateError('Una recarga de la venta ya no está disponible.');
        if (!_electronicBalance.supportsAmount(account, category, item.unitPrice)) throw StateError('Uno de los montos de recarga ya no está configurado.');
      }
    }

    if (oldSale.items.any((item) => item.isElectronicBalance)) {
      if (electronicBalanceProvider == null || !electronicBalanceProvider.reverseSale(oldSale.id)) throw StateError('No se pudo revertir el saldo electrónico de la venta.');
    }
    for (final entry in oldPhysical.entries) {
      final product = productProvider.findById(entry.key);
      if (product != null) productProvider.updateProduct(_stock.increase(product, entry.value));
    }

    final newSubtotal = updatedItems.fold<double>(0, (sum, item) {
      if (item.isElectronicBalance) return sum + item.unitPrice * item.quantity;
      final product = productProvider.findById(item.productId);
      return sum + (product == null ? item.unitPrice * item.quantity : _pricing.lineSubtotal(product, item.quantity));
    });
    final oldDiscountRate = oldSale.subtotal <= 0 ? 0.0 : oldSale.discountAmount / oldSale.subtotal;
    final newDiscountAmount = newSubtotal * oldDiscountRate;
    final cardBase = newSubtotal - newDiscountAmount;
    final oldCardBase = oldSale.subtotal - oldSale.discountAmount;
    final cardFeeRate = oldCardBase <= 0 ? 0.0 : oldSale.cardFeeAmount / oldCardBase;
    final newCardFeeAmount = cardBase * cardFeeRate;
    final newTotal = _totals.total(subtotal: newSubtotal, discountAmount: newDiscountAmount, cardFeeAmount: newCardFeeAmount);
    final newDiscountPercent = oldSale.subtotal <= 0 ? oldSale.discountPercent : oldDiscountRate * 100;

    final finalItems = <SaleItemRecord>[];
    for (final item in updatedItems) {
      final isElectronic = item.isElectronicBalance;
      final product = isElectronic ? null : productProvider.findById(item.productId);
      final account = isElectronic && item.electronicBalanceAccountId != null ? electronicBalanceProvider!.findAccount(item.electronicBalanceAccountId!) : null;
      final lineSubtotal = isElectronic ? item.unitPrice * item.quantity : (product == null ? item.unitPrice * item.quantity : _pricing.lineSubtotal(product, item.quantity));
      final lineDiscount = _totals.proportionalDiscount(lineSubtotal: lineSubtotal, subtotal: newSubtotal, discountAmount: newDiscountAmount);
      final cost = product?.cost ?? (account == null ? item.cost : _electronicBalance.providerCost(amount: item.unitPrice, commissionRate: account.commissionRate));
      final name = isElectronic && account != null ? '${account.companyName} · ${item.electronicBalanceCategory ?? item.unit}' : (product?.name ?? item.productName);
      final hasGroupPricing = !isElectronic && product != null && product.hasGroupPricing && product.groupQuantity > 0;
      final rebuilt = SaleItemRecord(id: item.id, productId: item.productId, productName: name, unit: product?.unit ?? item.unit, brand: product?.brand ?? item.brand, barcode: product?.barcode ?? item.barcode, cost: cost, unitPrice: product?.price ?? item.unitPrice, quantity: item.quantity, lineSubtotal: lineSubtotal, discount: lineDiscount, lineTotal: lineSubtotal - lineDiscount, imageData: product?.imageData ?? item.imageData, isElectronicBalance: isElectronic, hasGroupPricing: hasGroupPricing, electronicBalanceAccountId: item.electronicBalanceAccountId, electronicBalanceCategory: item.electronicBalanceCategory, metadata: item.metadata);
      finalItems.add(rebuilt);
    }
    for (final entry in newPhysical.entries) {
      final product = productProvider.findById(entry.key);
      if (product != null) productProvider.updateProduct(_stock.decrease(product, entry.value));
    }
    if (hasElectronic) {
      final groups = <String, List<SaleItemRecord>>{};
      for (final item in finalItems.where((item) => item.isElectronicBalance)) {
        final accountId = item.electronicBalanceAccountId;
        if (accountId != null) groups.putIfAbsent(accountId, () => []).add(item);
      }
      for (final entry in groups.entries) {
        final registered = electronicBalanceProvider!.registerSales(accountId: entry.key, saleId: oldSale.id, sales: entry.value.map((item) => ElectronicBalanceSale(amount: item.unitPrice, quantity: item.quantity, category: item.electronicBalanceCategory ?? item.unit, description: item.productName)).toList(growable: false));
        if (!registered) throw StateError('No se pudo registrar una de las recargas modificadas.');
      }
    }

    final updated = _lifecycle.touchForUpdate(oldSale, items: finalItems, subtotal: newSubtotal, discountPercent: newDiscountPercent, discountAmount: newDiscountAmount, cardFeeAmount: newCardFeeAmount, total: newTotal, received: oldSale.received, change: oldSale.change);
    _sales[index] = updated;
    notifyListeners();
    _persist(updated);
    return updated;
  }

  bool annulSale({
    required String saleId,
    required ProductProvider productProvider,
    ElectronicBalanceProvider? electronicBalanceProvider,
  }) {
    final index = _sales.indexWhere((sale) => sale.id == saleId);
    if (index < 0) return false;
    final sale = _sales[index];
    if (sale.isAnnulled) return false;
    if (sale.items.any((item) => item.isElectronicBalance)) {
      if (electronicBalanceProvider == null || !electronicBalanceProvider.reverseSale(sale.id)) return false;
    }
    for (final item in sale.items.where((item) => !item.isElectronicBalance)) {
      final product = productProvider.findById(item.productId);
      if (product != null) productProvider.updateProduct(_stock.increase(product, item.quantity));
    }
    final updated = sale.copyWith(status: SaleStatus.annulled, touchMetadata: true);
    _sales[index] = updated;
    notifyListeners();
    _persist(updated);
    return true;
  }

  List<SaleItemRecord> availableItemsForOperation(String saleId) {
    final sale = _sales.firstWhere((item) => item.id == saleId, orElse: () => throw StateError('La venta no existe.'));
    final byProduct = <String, SaleItemRecord>{};
    void add(SaleItemRecord item, int sign) {
      if (item.isElectronicBalance) return;
      final quantity = item.quantity * sign;
      final current = byProduct[item.productId];
      final nextQuantity = (current?.quantity ?? 0) + quantity;
      if (nextQuantity <= 0) {
        byProduct.remove(item.productId);
        return;
      }
      final source = current ?? item;
      byProduct[item.productId] = _withQuantity(source, nextQuantity);
    }
    for (final item in sale.items) add(item, 1);
    for (final operation in sale.operations) {
      for (final item in operation.itemsOut) add(item, -1);
      for (final item in operation.itemsIn) add(item, 1);
    }
    return byProduct.values.toList(growable: false);
  }

  SaleRecord returnItems({
    required String saleId,
    required Map<String, int> quantitiesByProduct,
    required ProductProvider productProvider,
  }) {
    final index = _sales.indexWhere((sale) => sale.id == saleId);
    if (index < 0) throw StateError('La venta no existe.');
    final sale = _sales[index];
    _ensureOperationAllowed(sale);
    if (quantitiesByProduct.isEmpty) throw StateError('Selecciona al menos un producto para devolver.');

    final available = {for (final item in availableItemsForOperation(saleId)) item.productId: item};
    final returned = <SaleItemRecord>[];
    for (final entry in quantitiesByProduct.entries) {
      final item = available[entry.key];
      final quantity = entry.value;
      if (item == null || quantity <= 0 || quantity > item.quantity) throw StateError('La cantidad a devolver no es válida para ${item?.productName ?? entry.key}.');
      if (productProvider.findById(item.productId) == null) throw StateError('El producto ${item.productName} ya no existe en el inventario.');
      returned.add(_withQuantity(item, quantity));
    }
    final amount = returned.fold(0.0, (sum, item) => sum + item.lineTotal);
    for (final item in returned) {
      final product = productProvider.findById(item.productId)!;
      productProvider.updateProduct(_stock.increase(product, item.quantity));
    }
    final operation = SaleOperationRecord(type: SaleOperationType.returnItem, createdAt: DateTime.now(), itemsOut: returned, amountDelta: -amount);
    final updated = sale.copyWith(operations: [...sale.operations, operation], touchMetadata: true);
    _sales[index] = updated;
    notifyListeners();
    _persist(updated);
    return updated;
  }

  SaleRecord changeItem({
    required String saleId,
    required String sourceProductId,
    required int quantity,
    required String replacementProductId,
    required ProductProvider productProvider,
  }) {
    final index = _sales.indexWhere((sale) => sale.id == saleId);
    if (index < 0) throw StateError('La venta no existe.');
    final sale = _sales[index];
    _ensureOperationAllowed(sale);
    if (sourceProductId == replacementProductId) throw StateError('El producto nuevo debe ser diferente al producto cambiado.');
    final available = availableItemsForOperation(saleId).firstWhere((item) => item.productId == sourceProductId, orElse: () => throw StateError('El producto a cambiar ya no está disponible.'));
    if (quantity <= 0 || quantity > available.quantity) throw StateError('La cantidad a cambiar no es válida.');
    final replacement = productProvider.findById(replacementProductId);
    if (replacement == null) throw StateError('El producto nuevo ya no existe.');
    if (replacement.stock < quantity) throw StateError('No hay suficiente existencia del producto nuevo para realizar el cambio.');

    final outgoing = _withQuantity(available, quantity);
    final incoming = _lines.physicalItem(replacement, quantity);
    final amountDelta = incoming.lineSubtotal - outgoing.lineTotal;

    final oldProduct = productProvider.findById(sourceProductId);
    if (oldProduct != null) productProvider.updateProduct(_stock.increase(oldProduct, quantity));
    productProvider.updateProduct(_stock.decrease(replacement, quantity));

    final operation = SaleOperationRecord(type: SaleOperationType.change, createdAt: DateTime.now(), itemsOut: [outgoing], itemsIn: [incoming], amountDelta: amountDelta);
    final updated = sale.copyWith(operations: [...sale.operations, operation], touchMetadata: true);
    _sales[index] = updated;
    notifyListeners();
    _persist(updated);
    return updated;
  }

  SaleRecord? findByTicketNumber(String ticketNumber) {
    final normalized = ticketNumber.trim().replaceFirst('#', '');
    if (normalized.isEmpty) return null;
    for (final sale in _sales) {
      if (sale.ticketNumber == normalized) return sale;
    }
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
    if (repository == null) {
      _loaded = true;
      return;
    }
    final stored = await repository.getAll();
    stored.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _sales
      ..clear()
      ..addAll(stored);
    if (_sales.isNotEmpty) {
      final maxTicket = _sales.map((sale) => int.tryParse(sale.ticketNumber) ?? 0).fold<int>(0, (max, value) => value > max ? value : max);
      _nextTicketNumber = maxTicket + 1;
    }
    _loaded = true;
    if (_sales.isNotEmpty) notifyListeners();
  }

  void _ensureOperationAllowed(SaleRecord sale) {
    if (sale.isAnnulled) throw StateError('La venta ya está anulada.');
    if (!sale.canOperateToday) throw StateError('Los cambios y devoluciones solo pueden realizarse el mismo día de la venta.');
    if (sale.items.any((item) => item.isElectronicBalance) && sale.items.every((item) => item.isElectronicBalance)) {
      throw StateError('Las recargas de saldo electrónico no admiten cambios ni devoluciones desde este módulo.');
    }
  }

  SaleItemRecord _withQuantity(SaleItemRecord item, int quantity) {
    final ratio = item.quantity <= 0 ? 0.0 : quantity / item.quantity;
    return SaleItemRecord(id: item.id, productId: item.productId, productName: item.productName, unit: item.unit, brand: item.brand, barcode: item.barcode, cost: item.cost, unitPrice: item.unitPrice, quantity: quantity, lineSubtotal: item.lineSubtotal * ratio, discount: item.discount * ratio, lineTotal: item.lineTotal * ratio, imageData: item.imageData, isElectronicBalance: item.isElectronicBalance, hasGroupPricing: item.hasGroupPricing, electronicBalanceAccountId: item.electronicBalanceAccountId, electronicBalanceCategory: item.electronicBalanceCategory, metadata: item.metadata);
  }

  void _persist(SaleRecord sale) {
    _repository?.save(sale).catchError((_) {});
  }

  void _persistDelete(String id) {
    _repository?.delete(id).catchError((_) {});
  }
}

class ElectronicBalanceCartSale {
  final String accountId;
  final String companyName;
  final String category;
  final double amount;
  final int quantity;
  final String description;

  const ElectronicBalanceCartSale({
    required this.accountId,
    this.companyName = '',
    required this.category,
    required this.amount,
    required this.quantity,
    String? description,
  }) : description = description ?? companyName;
}
