import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';

class SalesProvider extends ChangeNotifier {
  final List<SaleRecord> _sales = [];
  int _nextTicketNumber = 1;

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

    final items = <SaleItemRecord>[];

    for (final entry in cartQuantities.entries) {
      final product = productProvider.findById(entry.key);
      if (product == null) {
        throw StateError('Uno de los productos de la venta ya no existe.');
      }

      final quantity = entry.value;
      if (quantity <= 0) {
        throw StateError('La cantidad de un producto debe ser mayor que cero.');
      }

      final lineSubtotal = product.price * quantity;
      final lineDiscount = subtotal <= 0
          ? 0.0
          : discountAmount * (lineSubtotal / subtotal);
      final lineTotal = lineSubtotal - lineDiscount;

      items.add(
        SaleItemRecord(
          productId: product.id,
          productName: product.name,
          unit: product.unit,
          barcode: product.barcode,
          cost: product.cost,
          unitPrice: product.price,
          quantity: quantity,
          lineSubtotal: lineSubtotal,
          discount: lineDiscount,
          lineTotal: lineTotal,
          imageData: product.imageData,
        ),
      );
    }

    final balanceProvider = electronicBalanceProvider;
    final balanceAccounts = <String, ElectronicBalanceAccount>{};
    if (balanceProvider != null) {
      for (final sale in electronicSales) {
        final account = balanceProvider.findAccount(sale.accountId);
        if (account == null) {
          throw StateError('La compañía de una recarga ya no existe.');
        }
        if (sale.quantity <= 0 || sale.amount <= 0) {
          throw StateError('La cantidad de una recarga debe ser mayor que cero.');
        }
        if (!{'Saldo', 'Internet', 'Llamada'}.contains(sale.category)) {
          throw StateError('El tipo de recarga no es válido.');
        }
        if (account.amountsForCategory(sale.category).every(
              (amount) => (amount - sale.amount).abs() > 0.000001,
            )) {
          throw StateError(
            'El monto de una recarga ya no está configurado para ${account.companyName}.',
          );
        }
        balanceAccounts[sale.accountId] = account;
      }
    }

    for (final sale in electronicSales) {
      final account = balanceAccounts[sale.accountId]!;
      final lineSubtotal = sale.amount * sale.quantity;
      final lineDiscount = subtotal <= 0
          ? 0.0
          : discountAmount * (lineSubtotal / subtotal);
      final lineTotal = lineSubtotal - lineDiscount;
      final providerCost = sale.amount * (1 - account.commissionRate / 100);

      items.add(
        SaleItemRecord(
          productId:
              'electronic:${sale.accountId}:${sale.category}:${sale.amount.toStringAsFixed(4)}',
          productName:
              '${account.companyName} · ${sale.category} \$${_formatAmount(sale.amount)}',
          unit: sale.category,
          barcode: '',
          cost: providerCost,
          unitPrice: sale.amount,
          quantity: sale.quantity,
          lineSubtotal: lineSubtotal,
          discount: lineDiscount,
          lineTotal: lineTotal,
          isElectronicBalance: true,
          electronicBalanceAccountId: sale.accountId,
          electronicBalanceCategory: sale.category,
        ),
      );
    }

    if (items.isEmpty) {
      throw StateError('No hay líneas válidas para registrar la venta.');
    }

    if (electronicSales.isNotEmpty) {
      final registered = balanceProvider!.registerSales(
        accountId: electronicSales.first.accountId,
        sales: electronicSales
            .where((sale) => sale.accountId == electronicSales.first.accountId)
            .map(
              (sale) => ElectronicBalanceSale(
                amount: sale.amount,
                quantity: sale.quantity,
                category: sale.category,
                description: '${sale.companyName} · ${sale.category}',
              ),
            )
            .toList(),
      );
      if (!registered) {
        throw StateError('No se pudo registrar la venta de saldo.');
      }

      final accountIds = electronicSales
          .map((sale) => sale.accountId)
          .toSet()
          .skip(1)
          .toList();
      for (final accountId in accountIds) {
        final ok = balanceProvider.registerSales(
          accountId: accountId,
          sales: electronicSales
              .where((sale) => sale.accountId == accountId)
              .map(
                (sale) => ElectronicBalanceSale(
                  amount: sale.amount,
                  quantity: sale.quantity,
                  category: sale.category,
                  description: '${sale.companyName} · ${sale.category}',
                ),
              )
              .toList(),
        );
        if (!ok) {
          throw StateError('No se pudo registrar una de las ventas de saldo.');
        }
      }
    }

    final now = DateTime.now();
    final ticketNumber = nextTicketNumberPreview;

    final sale = SaleRecord(
      id: '${now.microsecondsSinceEpoch}-$ticketNumber',
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

    _sales.add(sale);
    _nextTicketNumber++;

    for (final item in items.where((item) => !item.isElectronicBalance)) {
      final product = productProvider.findById(item.productId);
      if (product == null) continue;
      productProvider.updateProduct(
        product.copyWith(stock: product.stock - item.quantity),
      );
    }

    notifyListeners();
    return sale;
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
    if (_sales.isEmpty) return;
    _sales.clear();
    _nextTicketNumber = 1;
    notifyListeners();
  }

  static String _formatAmount(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}

class ElectronicBalanceCartSale {
  final String accountId;
  final String companyName;
  final String category;
  final double amount;
  final int quantity;

  const ElectronicBalanceCartSale({
    required this.accountId,
    required this.companyName,
    required this.category,
    required this.amount,
    required this.quantity,
  });
}
