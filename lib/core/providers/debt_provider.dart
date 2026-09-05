import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/debt.dart';

class DebtProvider extends ChangeNotifier {
  final Map<String, DebtAccount> _accounts = {};
  final List<DebtMovement> _movements = [];

  List<DebtAccount> get accounts => List.unmodifiable(_accounts.values);
  List<DebtMovement> get movements => List.unmodifiable(_movements.reversed);

  double get totalDebt => _accounts.values.fold(0, (sum, account) => sum + account.totalDebt);
  double get totalPaid => _accounts.values.fold(0, (sum, account) => sum + account.totalPaid);
  double get totalRemaining => _accounts.values.fold(0, (sum, account) => sum + account.remaining);

  int get clientsWithDebt =>
      _accounts.values.where((account) => account.remaining > 0.005).length;

  DebtAccount? accountFor(String clientId) => _accounts[clientId];

  void recordDebt({
    required String clientId,
    required String clientName,
    required double amount,
    String? reference,
    DateTime? createdAt,
  }) {
    if (clientId.trim().isEmpty || amount <= 0) return;

    final current = _accounts[clientId];
    _accounts[clientId] = DebtAccount(
      clientId: clientId,
      clientName: clientName,
      totalDebt: (current?.totalDebt ?? 0) + amount,
      totalPaid: current?.totalPaid ?? 0,
    );

    _movements.add(
      DebtMovement(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        clientId: clientId,
        clientName: clientName,
        type: DebtMovementType.debt,
        amount: amount,
        createdAt: createdAt ?? DateTime.now(),
        reference: reference,
      ),
    );
    notifyListeners();
  }

  bool recordPayment({
    required String clientId,
    required String clientName,
    required double amount,
  }) {
    if (clientId.trim().isEmpty || amount <= 0) return false;

    final current = _accounts[clientId];
    if (current == null || current.remaining <= 0) return false;
    if (amount > current.remaining + 0.005) return false;

    _accounts[clientId] = current.copyWith(
      totalPaid: current.totalPaid + amount,
      clientName: clientName,
    );

    _movements.add(
      DebtMovement(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        clientId: clientId,
        clientName: clientName,
        type: DebtMovementType.payment,
        amount: amount,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  void renameClient(String clientId, String clientName) {
    final current = _accounts[clientId];
    if (current == null) return;
    _accounts[clientId] = current.copyWith(clientName: clientName);
    notifyListeners();
  }
}
