import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/sale.dart';
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
  }) {
    if (cartQuantities.isEmpty) {
      throw StateError('No hay productos seleccionados.');
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
        ),
      );
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

    // Las ventas no se bloquean por falta de inventario. El stock puede
    // quedar negativo y posteriormente compensarse con compras.
    for (final item in items) {
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
}
