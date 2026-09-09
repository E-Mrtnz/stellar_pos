import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';

/// Pure debt calculations. No Flutter state or persistence belongs here.
class DebtService {
  const DebtService();

  List<SaleRecord> creditSales(Iterable<SaleRecord> sales) => sales
      .where((sale) => sale.paymentMethod == 'Fiado' && sale.clientId != null)
      .toList(growable: false);

  double totalDebt(Iterable<SaleRecord> sales) =>
      creditSales(sales).fold(0, (sum, sale) => sum + sale.effectiveTotal);

  double totalPaid(Iterable<DebtMovement> payments) =>
      payments.fold(0, (sum, payment) => sum + payment.amount);

  double paidForClient(String clientId, Iterable<DebtMovement> payments) =>
      payments.where((payment) => payment.clientId == clientId).fold(0, (sum, payment) => sum + payment.amount);

  DebtAccount? accountFor(String clientId, Iterable<SaleRecord> sales, Iterable<DebtMovement> payments) {
    final matching = creditSales(sales).where((sale) => sale.clientId == clientId).toList(growable: false);
    if (matching.isEmpty) return null;
    return DebtAccount(
      clientId: clientId,
      clientName: matching.last.clientName,
      totalDebt: matching.fold(0, (sum, sale) => sum + sale.effectiveTotal),
      totalPaid: paidForClient(clientId, payments),
    );
  }

  List<DebtAccount> accounts(Iterable<SaleRecord> sales, Iterable<DebtMovement> payments) {
    final byClient = <String, DebtAccount>{};
    for (final sale in creditSales(sales)) {
      final clientId = sale.clientId!;
      final current = byClient[clientId];
      byClient[clientId] = DebtAccount(
        clientId: clientId,
        clientName: sale.clientName,
        totalDebt: (current?.totalDebt ?? 0) + sale.effectiveTotal,
        totalPaid: paidForClient(clientId, payments),
      );
    }
    return byClient.values.toList(growable: false);
  }

  double appliedPayment({required double amount, required double remaining, double? maxAmount}) {
    if (amount <= 0 || remaining <= 0.005) return 0;
    final limit = maxAmount ?? remaining;
    if (limit <= 0) return 0;
    return amount > limit ? limit : amount;
  }
}
