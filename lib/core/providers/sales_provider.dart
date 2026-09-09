import 'package:flutter/foundation.dart';
import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/domain/services/electronic_balance_service.dart';
import 'package:stellar_pos/core/domain/services/inventory_stock_service.dart';
import 'package:stellar_pos/core/domain/services/sale_lifecycle_service.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
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
        _electronicBalance =
            electronicBalance ?? AppDependencies.electronicBalance,
        _lifecycle = lifecycle ?? AppDependencies.saleLifecycle;

  List<SaleRecord> get sales => List.unmodifiable(_sales);
  SaleRecord? get latestSale => _sales.isEmpty ? null : _sales.last;
  String get nextTicketNumberPreview =>
      _nextTicketNumber.toString().padLeft(8, '0');

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

    final now = DateTime.now();
    final ticketNumber = nextTicketNumberPreview;
    final saleId = _lifecycle.newSaleId();
    final items = <SaleItemRecord>[];

    for (final entry in cartQuantities.entries) {
      final product = productProvider.findById(entry.key);
      if (product == null) {
        throw StateError('Uno de los productos de la venta ya no existe.');
      }
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
        if (account == null) {
          throw StateError('La compañía de una recarga ya no existe.');
        }
        if (electronicSale.quantity <= 0 || electronicSale.amount <= 0) {
          throw StateError('La cantidad de una recarga debe ser mayor que cero.');
        }
        if (!_electronicBalance.isValidCategory(electronicSale.category)) {
          throw StateError('El tipo de recarga no es válido.');
        }
        if (!_electronicBalance.supportsAmount(
          account,
          electronicSale.category,
          electronicSale.amount,
        )) {
          throw StateError(
            'El monto de una recarga ya no está configurado para ${account.companyName}.',
          );
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
        productId:
            'electronic:${electronicSale.accountId}:${electronicSale.category}:${electronicSale.amount.toStringAsFixed(4)}',
        productName: electronicSale.description,
        quantity: electronicSale.quantity,
        unitPrice: electronicSale.amount,
        cost: providerCost,
        lineSubtotal: lineSubtotal,
        discountAmount: lineDiscount,
        hasGroupPricing: false,
      ));
    }

    final sale = SaleRecord(
      id: saleId,
      ticketNumber: ticketNumber,
      createdAt: now,
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
        productProvider.updateProduct(
          _stock.decrease(product, entry.value),
        );
      }
    }

    if (balanceProvider != null) {
      for (final electronicSale in electronicSales) {
        final account = balanceProvider.findAccount(electronicSale.accountId);
        if (account != null) {
          balanceProvider.registerSale(
            account: account,
            category: electronicSale.category,
            amount: electronicSale.amount,
            quantity: electronicSale.quantity,
            saleId: sale.id,
          );
        }
      }
    }

    _sales.add(sale);
    _nextTicketNumber++;
    notifyListeners();
    return sale;
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
