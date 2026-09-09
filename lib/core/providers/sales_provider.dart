import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
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

  final ProductPricingService _pricing;
  final SaleLinesService _lines;
  final SaleTotalsService _totals;
  final InventoryStockService _stock;
  final ElectronicBalanceService _electronicBalance;
  final SaleLifecycleService _lifecycle;

  SalesProvider({
    ProductPricingService? pricing,
    SaleLinesService? lines,
    SaleTotalsService? totals,
    InventoryStockService? stock,
    ElectronicBalanceService? electronicBalance,
    SaleLifecycleService? lifecycle,
  })  : _pricing = pricing ?? AppDependencies.productPricing,
        _lines = lines ?? AppDependencies.saleLines,
        _totals = totals ?? AppDependencies.saleTotals,
        _stock = stock ?? AppDependencies.inventoryStock,
        _electronicBalance = electronicBalance ?? AppDependencies.electronicBalance,
        _lifecycle = lifecycle ?? AppDependencies.saleLifecycle;

  List<SaleRecord> get sales => List.unmodifiable(_sales);
  SaleRecord? get latestSale => _sales.isEmpty ? null : _sales.last;
  String get nextTicketNumberPreview => _nextTicketNumber.toString().padLeft(8, '0');

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
      if (product != null) productProvider.updateProduct(_stock.decrease(product, entry.value));
    }

    if (balanceProvider != null && electronicSales.isNotEmpty) {
      for (final entry in electronicSales.map((e) => e.accountId).toSet()) {
        final accountSales = electronicSales.where((sale) => sale.accountId == entry).map(
          (sale) => ElectronicBalanceSale(
            amount: sale.amount,
            quantity: sale.quantity,
            category: sale.category,
            description: sale.description,
          ),
        ).toList(growable: false);
        if (!balanceProvider.registerSales(accountId: entry, sales: accountSales, saleId: sale.id)) {
          throw StateError('No se pudo registrar una de las ventas de saldo.');
        }
      }
    }

    _sales.add(sale);
    _nextTicketNumber++;
    notifyListeners();
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
        if (!_electronicBalance.supportsAmount(account, category, item.unitPrice)) {
          throw StateError('Uno de los montos de recarga ya no está configurado.');
        }
      }
    }

    if (oldSale.items.any((item) => item.isElectronicBalance)) {
      if (electronicBalanceProvider == null || !electronicBalanceProvider.reverseSale(oldSale.id)) {
        throw StateError('No se pudo revertir el saldo electrónico de la venta.');
      }
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
    final cardFeeRate = cardBase <= 0 ? 0.0 : oldSale.cardFeeAmount / (oldSale.subtotal - oldSale.discountAmount);
    final newCardFeeAmount = cardBase * cardFeeRate;
    final newTotal = _totals.total(subtotal: newSubtotal, discountAmount: newDiscountAmount, cardFeeAmount: newCardFeeAmount);
    final newDiscountPercent = oldSale.subtotal <= 0 ? oldSale.discountPercent : oldDiscountRate * 100;

    final finalItems = <SaleItemRecord>[];
    for (final item in updatedItems) {
      final isElectronic = item.isElectronicBalance;
      final product = isElectronic ? null : productProvider.findById(item.productId);
      final account = isElectronic && item.electronicBalanceAccountId != null
          ? electronicBalanceProvider!.findAccount(item.electronicBalanceAccountId!)
          : null;
      final lineSubtotal = isElectronic
          ? item.unitPrice * item.quantity
          : (product == null ? item.unitPrice * item.quantity : _pricing.lineSubtotal(product, item.quantity));
      final lineDiscount = _totals.proportionalDiscount(
        lineSubtotal: lineSubtotal,
        subtotal: newSubtotal,
        discountAmount: newDiscountAmount,
      );
      final cost = product?.cost ?? (account == null ? item.cost : _electronicBalance.providerCost(amount: item.unitPrice, commissionRate: account.commissionRate));
      final name = isElectronic && account != null
          ? '${account.companyName} · ${item.electronicBalanceCategory ?? item.unit}'
          : (product?.name ?? item.productName);
      final hasGroupPricing = !isElectronic && product != null && product.hasGroupPricing && product.groupQuantity > 0;
      final rebuilt = SaleItemRecord(
        id: item.id,
        productId: item.productId,
        productName: name,
        unit: product?.unit ?? item.unit,
        brand: product?.brand ?? item.brand,
        barcode: product?.barcode ?? item.barcode,
        cost: cost,
        unitPrice: product?.price ?? item.unitPrice,
        quantity: item.quantity,
        lineSubtotal: lineSubtotal,
        discount: lineDiscount,
        lineTotal: lineSubtotal - lineDiscount,
        imageData: product?.imageData ?? item.imageData,
        isElectronicBalance: isElectronic,
        hasGroupPricing: hasGroupPricing,
        electronicBalanceAccountId: item.electronicBalanceAccountId,
        electronicBalanceCategory: item.electronicBalanceCategory,
        metadata: item.metadata,
      );
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
        final registered = electronicBalanceProvider!.registerSales(
          accountId: entry.key,
          saleId: oldSale.id,
          sales: entry.value.map((item) => ElectronicBalanceSale(
            amount: item.unitPrice,
            quantity: item.quantity,
            category: item.electronicBalanceCategory ?? item.unit,
            description: item.productName,
          )).toList(growable: false),
        );
        if (!registered) throw StateError('No se pudo registrar una de las recargas modificadas.');
      }
    }

    final updated = _lifecycle.touchForUpdate(
      oldSale,
      items: finalItems,
      subtotal: newSubtotal,
      discountPercent: newDiscountPercent,
      discountAmount: newDiscountAmount,
      cardFeeAmount: newCardFeeAmount,
      total: newTotal,
      received: oldSale.received,
      change: oldSale.change,
    );
    _sales[index] = updated;
    notifyListeners();
    return updated;
  }

  bool deleteSale({
    required String saleId,
    required ProductProvider productProvider,
    ElectronicBalanceProvider? electronicBalanceProvider,
  }) {
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
    return true;
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
    _sales.clear();
    _nextTicketNumber = 1;
    notifyListeners();
  }
}

class ElectronicBalanceCartSale {
  final String accountId;
  final String category;
  final double amount;
  final int quantity;
  final String description;

  const ElectronicBalanceCartSale({
    required this.accountId,
    required this.category,
    required this.amount,
    required this.quantity,
    required this.description,
  });
}
