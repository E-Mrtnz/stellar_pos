import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/domain/services/debt_service.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class DebtProvider extends ChangeNotifier {
  final SalesProvider _salesProvider;
  final DebtService _service;
  final List<DebtMovement> _payments = [];

  DebtProvider(this._salesProvider, {DebtService? service})
      : _service = service ?? AppDependencies.debt {
    _salesProvider.addListener(_onSalesChanged);
  }

  List<DebtAccount> get accounts => List.unmodifiable(
        _service.accounts(_salesProvider.sales, _payments),
      );

  List<DebtMovement> get movements {
    final result = <DebtMovement>[
      ..._service.creditSales(_salesProvider.sales).map(
            (sale) => DebtMovement(
              id: sale.id,
              clientId: sale.clientId ?? '',
              clientName: sale.clientName,
              type: DebtMovementType.debt,
              amount: sale.total,
              createdAt: sale.createdAt,
              reference: sale.ticketNumber,
            ),
          ),
      ..._payments,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(result);
  }

  double get totalDebt => _service.totalDebt(_salesProvider.sales);
  double get totalPaid => _service.totalPaid(_payments);
  double get totalRemaining =>
      (totalDebt - totalPaid).clamp(0, double.infinity).toDouble();
  int get clientsWithDebt => accounts.where((a) => a.remaining > 0.005).length;

  DebtAccount? accountFor(String clientId) => _service.accountFor(
        clientId,
        _salesProvider.sales,
        _payments,
      );

  double paidForClient(String clientId) =>
      _service.paidForClient(clientId, _payments);

  bool recordPayment({
    required String clientId,
    required String clientName,
    required double amount,
    double? maxAmount,
  }) {
    final account = accountFor(clientId);
    final appliedAmount = _service.appliedPayment(
      amount: amount,
      remaining: account?.remaining ?? 0,
      maxAmount: maxAmount,
    );
    if (clientId.trim().isEmpty || appliedAmount <= 0) return false;

    final now = DateTime.now();
    String? reference;
    final recentSales = _service
        .creditSales(_salesProvider.sales)
        .where(
          (sale) =>
              sale.clientId == clientId &&
              sale.received > 0.005 &&
              sale.received < sale.total - 0.005 &&
              now.difference(sale.createdAt).inMilliseconds.abs() <= 2000,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final sale in recentSales) {
      if (!_payments.any((payment) => payment.reference == sale.id)) {
        reference = sale.id;
        break;
      }
    }

    _payments.add(
      DebtMovement(
        id: IdGenerator.newId(),
        clientId: clientId,
        clientName: clientName,
        type: DebtMovementType.payment,
        amount: appliedAmount,
        createdAt: now,
        reference: reference,
      ),
    );
    notifyListeners();
    return true;
  }

  void syncInitialPayment({
    required String saleId,
    required String clientId,
    required String clientName,
    required double amount,
  }) {
    final existing = _payments.where((payment) => payment.reference == saleId).toList();
    final originalCreatedAt = existing.isEmpty ? null : existing.first.createdAt;
    _payments.removeWhere((payment) => payment.reference == saleId);
    final appliedAmount = amount.clamp(0, double.infinity).toDouble();
    if (appliedAmount > 0.005) {
      _payments.add(
        DebtMovement(
          id: IdGenerator.newId(),
          clientId: clientId,
          clientName: clientName,
          type: DebtMovementType.payment,
          amount: appliedAmount,
          createdAt: originalCreatedAt ?? DateTime.now(),
          reference: saleId,
        ),
      );
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
        metadata: movement.metadata,
      );
      changed = true;
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _salesProvider.removeListener(_onSalesChanged);
    super.dispose();
  }

  void _onSalesChanged() => notifyListeners();
}
