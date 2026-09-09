import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class DebtProvider extends ChangeNotifier {
  final SalesProvider _salesProvider;
  final List<DebtMovement> _payments = [];

  DebtProvider(this._salesProvider) {
    _salesProvider.addListener(_onSalesChanged);
  }

  List<DebtAccount> get accounts {
    final byClient = <String, DebtAccount>{};
    for (final sale in _creditSales) {
      final clientId = sale.clientId;
      if (clientId == null || clientId.isEmpty) continue;
      final current = byClient[clientId];
      byClient[clientId] = DebtAccount(
        clientId: clientId,
        clientName: sale.clientName,
        totalDebt: (current?.totalDebt ?? 0) + sale.total,
        totalPaid: paidForClient(clientId),
      );
    }
    return List.unmodifiable(byClient.values);
  }

  List<DebtMovement> get movements {
    final result = <DebtMovement>[
      ..._creditSales.map((sale) => DebtMovement(
            id: sale.id,
            clientId: sale.clientId ?? '',
            clientName: sale.clientName,
            type: DebtMovementType.debt,
            amount: sale.total,
            createdAt: sale.createdAt,
            reference: sale.ticketNumber,
          )),
      ..._payments,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(result);
  }

  double get totalDebt => _creditSales.fold(0, (sum, sale) => sum + sale.total);
  double get totalPaid => _payments.fold(0, (sum, payment) => sum + payment.amount);
  double get totalRemaining => (totalDebt - totalPaid).clamp(0, double.infinity).toDouble();
  int get clientsWithDebt => accounts.where((a) => a.remaining > 0.005).length;

  DebtAccount? accountFor(String clientId) {
    final sales = _creditSales.where((sale) => sale.clientId == clientId).toList();
    if (sales.isEmpty) return null;
    return DebtAccount(
      clientId: clientId,
      clientName: sales.last.clientName,
      totalDebt: sales.fold(0, (sum, sale) => sum + sale.total),
      totalPaid: paidForClient(clientId),
    );
  }

  double paidForClient(String clientId) => _payments
      .where((movement) => movement.clientId == clientId)
      .fold(0, (sum, movement) => sum + movement.amount);

  bool recordPayment({required String clientId, required String clientName, required double amount, double? maxAmount}) {
    final account = accountFor(clientId);
    final remaining = account?.remaining ?? 0;
    final limit = maxAmount ?? remaining;
    if (clientId.trim().isEmpty || amount <= 0 || remaining <= 0.005 || limit <= 0) return false;

    final appliedAmount = amount > limit ? limit : amount;
    if (appliedAmount <= 0) return false;

    final now = DateTime.now();
    String? reference;
    final recentSales = _creditSales
        .where((sale) => sale.clientId == clientId && sale.received > 0.005 && sale.received < sale.total - 0.005 && now.difference(sale.createdAt).inMilliseconds.abs() <= 2000)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final sale in recentSales) {
      if (!_payments.any((payment) => payment.reference == sale.id)) {
        reference = sale.id;
        break;
      }
    }

    _payments.add(DebtMovement(
      id: IdGenerator.newId(),
      clientId: clientId,
      clientName: clientName,
      type: DebtMovementType.payment,
      amount: appliedAmount,
      createdAt: now,
      reference: reference,
    ));
    notifyListeners();
    return true;
  }

  void syncInitialPayment({required String saleId, required String clientId, required String clientName, required double amount}) {
    final existing = _payments.where((payment) => payment.reference == saleId).toList();
    final originalCreatedAt = existing.isEmpty ? null : existing.first.createdAt;
    _payments.removeWhere((payment) => payment.reference == saleId);
    final appliedAmount = amount.clamp(0, double.infinity).toDouble();
    if (appliedAmount > 0.005) {
      _payments.add(DebtMovement(
        id: IdGenerator.newId(),
        clientId: clientId,
        clientName: clientName,
        type: DebtMovementType.payment,
        amount: appliedAmount,
        createdAt: originalCreatedAt ?? DateTime.now(),
        reference: saleId,
      ));
    }
    notifyListeners();
  }

  void renameClient(String clientId, String clientName) {
    var changed = false;
    for (var i = 0; i < _payments.length; i++) {
      final movement = _payments[i];
      if (movement.clientId != clientId || movement.clientName == clientName) continue;
      _payments[i] = DebtMovement(
        id: movement.id,
        clientId: movement.clientId,
        clientName: clientName,
        type: movement.type,
        amount: movement.amount,
        createdAt: movement.createdAt,
        reference: movement.reference,
      );
      changed = true;
    }
    if (changed) notifyListeners();
  }

  List<SaleRecord> get _creditSales => _salesProvider.sales
      .where((sale) => sale.paymentMethod == 'Fiado' && sale.clientId != null)
      .toList(growable: false);

  void _onSalesChanged() => notifyListeners();

  @override
  void dispose() {
    _salesProvider.removeListener(_onSalesChanged);
    super.dispose();
  }
}
