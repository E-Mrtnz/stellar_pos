import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/providers/debt_provider.dart';

class DebtPaymentActions {
  const DebtPaymentActions._();

  static Future<bool> edit(BuildContext context, DebtMovement movement) async {
    final controller = TextEditingController(
      text: movement.amount.toStringAsFixed(2),
    );
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Editar abono'),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto del abono',
                prefixText: '\$ ',
                helperText: 'Modifica únicamente el valor del abono.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa un monto válido mayor que \$0.00.'),
                    ),
                  );
                  return;
                }
                final updated = context.read<DebtProvider>().updatePayment(
                  paymentId: movement.id,
                  amount: amount,
                );
                if (!updated) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No se pudo actualizar el abono. El monto no puede superar la deuda disponible.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      return saved ?? false;
    } finally {
      controller.dispose();
    }
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
