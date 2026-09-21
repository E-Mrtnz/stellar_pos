import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/providers/debt_provider.dart';
import 'package:stellar_pos/presentation/debts/debt_payment_dialog.dart';

class DebtPaymentActions {
  const DebtPaymentActions._();

  static Future<bool> edit(BuildContext context, DebtMovement movement) async {
    final debtProvider = context.read<DebtProvider>();
    final account = debtProvider.accountFor(movement.clientId);
    final editableDebt = account == null
        ? movement.amount
        : account.remaining + movement.amount;

    final amount = await DebtPaymentDialog.show(
      context,
      clientName: movement.clientName,
      debt: editableDebt,
      initialAmount: movement.amount,
      editing: true,
    );
    if (amount == null || !context.mounted) return false;

    final updated = debtProvider.updatePayment(
      paymentId: movement.id,
      amount: amount,
    );
    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar el abono. El monto no puede superar la deuda disponible.',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  static Future<bool> delete(
    BuildContext context,
    DebtMovement movement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar abono'),
        content: Text(
          '¿Deseas eliminar el abono de \$' +
              movement.amount.toStringAsFixed(2) +
              ' de ' +
              movement.clientName +
              '?\n\nEsta acción eliminará el registro y el monto dejará de aplicarse a la deuda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
            ),
            onPressed: () {
              final deleted = context.read<DebtProvider>().deletePayment(
                movement.id,
              );
              if (!deleted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo eliminar el abono.'),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
