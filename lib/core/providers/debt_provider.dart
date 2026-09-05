import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/debt.dart';

class DebtProvider extends ChangeNotifier {
  final List<DebtMovement> _payments = [];

  List<DebtMovement> get payments => List.unmodifiable(_payments.reversed);

  double paidForClient(String clientId) => _payments
      .where((movement) => movement.clientId == clientId)
      .fold(0, (sum, movement) => sum + movement.amount);

  bool recordPayment({
    required String clientId,
    required String clientName,
    required double amount,
    double? maxAmount,
  }) {
    if (clientId.trim().isEmpty || amount <= 0) return false;
    if (maxAmount != null && amount > maxAmount + 0.005) return false;

    _payments.add(
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
    var changed = false;
    for (var index = 0; index < _payments.length; index++) {
      final movement = _payments[index];
      if (movement.clientId != clientId || movement.clientName == clientName) continue;
      _payments[index] = DebtMovement(
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
}
