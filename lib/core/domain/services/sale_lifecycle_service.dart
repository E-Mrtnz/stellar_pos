import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

/// Pure lifecycle rules for sales. Persistence and UI stay outside this class.
class SaleLifecycleService {
  const SaleLifecycleService();

  String newSaleId() => IdGenerator.newId();

  SaleRecord touchForUpdate(
    SaleRecord sale, {
    required List<SaleItemRecord> items,
    required double subtotal,
    required double discountPercent,
    required double discountAmount,
    required double cardFeeAmount,
    required double total,
    double? received,
    double? change,
  }) {
    return SaleRecord(
      id: sale.id,
      ticketNumber: sale.ticketNumber,
      createdAt: sale.createdAt,
      clientId: sale.clientId,
      clientName: sale.clientName,
      paymentMethod: sale.paymentMethod,
      items: List.unmodifiable(items),
      subtotal: subtotal,
      discountPercent: discountPercent,
      discountAmount: discountAmount,
      cardFeeAmount: cardFeeAmount,
      total: total,
      received: received ?? sale.received,
      change: change ?? sale.change,
      status: sale.status,
      operations: sale.operations,
      metadata: sale.metadata.touch(),
    );
  }
}
