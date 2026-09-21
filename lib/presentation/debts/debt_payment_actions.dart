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
    final currentDebt = account?.remaining ?? movement.amount;

    final amount = await DebtPaymentDialog.show(
      context,
      clientName: movement.clientName,
      debt: currentDebt,
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
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
        ),
        child: Container(
          width: 430,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.dangerRed.withAlpha(18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.dangerRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Eliminar abono',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withAlpha(8),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.dangerRed.withAlpha(28)),
                ),
                child: Text(
                  '¿Deseas eliminar el abono de \$' +
                      movement.amount.toStringAsFixed(2) +
                      ' de ' +
                      movement.clientName +
                      '?',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Esta acción eliminará el registro y el monto dejará de aplicarse a la deuda.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Cancelar',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: FilledButton.icon(
                        onPressed: () {
                          final deleted = context.read<DebtProvider>().deletePayment(movement.id);
                          if (!deleted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('No se pudo eliminar el abono.')),
                            );
                            return;
                          }
                          Navigator.pop(dialogContext, true);
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 15),
                        label: const Text(
                          'Eliminar',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.dangerRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed ?? false;
  }
}
