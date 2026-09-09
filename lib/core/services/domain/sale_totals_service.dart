import 'package:stellar_pos/core/models/sale.dart';

class SaleTotalsService {
  const SaleTotalsService();

  double proportionalDiscount({required double lineSubtotal, required double subtotal, required double discountAmount}) {
    if (subtotal <= 0 || lineSubtotal <= 0 || discountAmount <= 0) return 0;
    return discountAmount * (lineSubtotal / subtotal);
  }

  double subtotal(Iterable<SaleItemRecord> items) => items.fold(0, (sum, item) => sum + item.lineSubtotal);

  double total({required double subtotal, required double discountAmount, required double cardFeeAmount}) => subtotal - discountAmount + cardFeeAmount;
}
