import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';

class ElectronicBalanceLayout extends StatelessWidget {
  const ElectronicBalanceLayout({super.key});

  Future<void> _showAccountDialog(BuildContext context, [ElectronicBalanceAccount? account]) async {
    final nameController = TextEditingController(text: account?.companyName ?? '');
    final rateController = TextEditingController(
      text: account == null ? '' : _formatNumber(account.commissionRate),
    );

    await showDialog<void>(
      context: context,
      builder: (_) => _BalanceAccountDialog(
        account: account,
        nameController: nameController,
        rateController: rateController,
      ),
    );
    nameController.dispose();
    rateController.dispose();
  }

  Future<void> _showPurchaseDialog(
    BuildContext context,
    ElectronicBalanceAccount account,
  ) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => _BalancePurchaseDialog(
        account: account,
        controller: controller,
      ),
    );
    controller.dispose();
  }

  Future<void> _showSaleDialog(
    BuildContext context,
    ElectronicBalanceAccount account,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BalanceSaleDialog(account: account),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ElectronicBalanceProvider>();

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Saldo electrónico',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showAccountDialog(context),
                icon: const Icon(Icons.add, size: 19),
                label: const Text('Agregar compañía'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: provider.accounts.isEmpty
                ? _EmptyBalanceState(onCreate: () => _showAccountDialog(context))
                : ListView.separated(
                    itemCount: provider.accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final account = provider.accounts[index];
                      return _BalanceAccountCard(
                        account: account,
                        purchased: provider.totalPurchased(account.id),
                        sold: provider.totalSold(account.id),
                        profit: provider.totalProfit(account.id),
                        onPurchase: () => _showPurchaseDialog(context, account),
                        onSale: () => _showSaleDialog(context, account),
                        onEdit: () => _showAccountDialog(context, account),
                        onDelete: () => _deleteAccount(context, account),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(
    BuildContext context,
    ElectronicBalanceAccount account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar compañía'),
        content: Text('¿Deseas eliminar ${account.companyName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final removed = context.read<ElectronicBalanceProvider>().removeAccount(account.id);
    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede eliminar una compañía con movimientos registrados.'),
        ),
      );
    }
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}

class _BalanceAccountCard extends StatelessWidget {
  final ElectronicBalanceAccount account;
  final double purchased;
  final double sold;
  final double profit;
  final VoidCallback onPurchase;
  final VoidCallback onSale;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BalanceAccountCard({
    required this.account,
    required this.purchased,
    required this.sold,
    required this.profit,
    required this.onPurchase,
    required this.onSale,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sim_card_outlined, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.companyName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Comisión: ${account.commissionRate.toStringAsFixed(2)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _BalanceMetric(label: 'Disponible', value: account.balance, emphasize: true),
                _BalanceMetric(label: 'Comprado', value: purchased),
                _BalanceMetric(label: 'Utilizado', value: sold),
                _BalanceMetric(label: 'Ganancia', value: profit),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPurchase,
                    icon: const Icon(Icons.add_card_outlined, size: 18),
                    label: const Text('Comprar saldo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSale,
                    icon: const Icon(Icons.point_of_sale_outlined, size: 18),
                    label: const Text('Vender saldo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasize;

  const _BalanceMetric({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: emphasize ? 16 : 13,
              fontWeight: FontWeight.bold,
              color: emphasize ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBalanceState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyBalanceState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sim_card_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 10),
          const Text(
            'No hay compañías de saldo registradas',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Agregar compañía'),
          ),
        ],
      ),
    );
  }
}

class _BalanceAccountDialog extends StatelessWidget {
  final ElectronicBalanceAccount? account;
  final TextEditingController nameController;
  final TextEditingController rateController;

  const _BalanceAccountDialog({
    required this.account,
    required this.nameController,
    required this.rateController,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(account == null ? 'Agregar compañía' : 'Editar compañía'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Compañía',
                hintText: 'Ej. Tigo',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Comisión (%)',
                hintText: 'Ej. 5',
                suffixText: '%',
                prefixIcon: Icon(Icons.percent_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final rate = double.tryParse(rateController.text.replaceAll(',', '.'));
            final provider = context.read<ElectronicBalanceProvider>();
            final ok = account == null
                ? provider.addAccount(
                    companyName: nameController.text,
                    commissionRate: rate ?? -1,
                  )
                : provider.updateAccount(
                    id: account!.id,
                    companyName: nameController.text,
                    commissionRate: rate ?? -1,
                  );
            if (!ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Revisa el nombre y la comisión (0% a 100%).')),
              );
              return;
            }
            Navigator.pop(context);
          },
          child: Text(account == null ? 'Agregar' : 'Guardar'),
        ),
      ],
    );
  }
}

class _BalancePurchaseDialog extends StatelessWidget {
  final ElectronicBalanceAccount account;
  final TextEditingController controller;

  const _BalancePurchaseDialog({required this.account, required this.controller});

  @override
  Widget build(BuildContext context) {
    final commission = account.commissionRate / 100;
    return AlertDialog(
      title: const Text('Comprar saldo'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.companyName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Comisión aplicada: ${account.commissionRate.toStringAsFixed(2)}%'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Saldo comprado',
                prefixText: '\$',
              ),
              onChanged: (_) {},
            ),
            const SizedBox(height: 8),
            Text(
              'Ejemplo: \$20 de saldo → costo real \$${(20 * (1 - commission)).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(controller.text.replaceAll(',', '.'));
            final ok = amount != null &&
                context.read<ElectronicBalanceProvider>().registerPurchase(
                      accountId: account.id,
                      amount: amount,
                    );
            if (!ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ingresa un monto válido mayor que cero.')),
              );
              return;
            }
            Navigator.pop(context);
          },
          child: const Text('Registrar compra'),
        ),
      ],
    );
  }
}

class _BalanceSaleDialog extends StatefulWidget {
  final ElectronicBalanceAccount account;
  const _BalanceSaleDialog({required this.account});

  @override
  State<_BalanceSaleDialog> createState() => _BalanceSaleDialogState();
}

class _BalanceSaleDialogState extends State<_BalanceSaleDialog> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'Saldo';

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final profit = amount * account.commissionRate / 100;
    final cost = amount - profit;

    return AlertDialog(
      title: const Text('Vender saldo'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${account.companyName} · Disponible: \$${account.balance.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Tipo de venta'),
              items: const [
                DropdownMenuItem(value: 'Saldo', child: Text('Saldo')),
                DropdownMenuItem(value: 'Internet', child: Text('Internet')),
                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
              ],
              onChanged: (value) => setState(() => _category = value ?? 'Saldo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto de saldo utilizado',
                prefixText: '\$',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ej. Paquete de 2 días',
              ),
            ),
            if (amount > 0) ...[
              const SizedBox(height: 12),
              Text('Cliente paga: \$${amount.toStringAsFixed(2)}'),
              Text('Costo del saldo: \$${cost.toStringAsFixed(2)}'),
              Text(
                'Ganancia: \$${profit.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final value = double.tryParse(_amountController.text.replaceAll(',', '.'));
            if (value == null || value <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ingresa un monto válido mayor que cero.')),
              );
              return;
            }
            if (value > account.balance) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('El monto supera el saldo disponible.')),
              );
              return;
            }

            final ok = context.read<ElectronicBalanceProvider>().registerSale(
                  accountId: account.id,
                  amount: value,
                  category: _category,
                  description: _descriptionController.text,
                );
            if (!ok) return;
            Navigator.pop(context);
          },
          child: const Text('Registrar venta'),
        ),
      ],
    );
  }
}
