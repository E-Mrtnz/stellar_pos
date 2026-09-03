import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';

class ElectronicBalanceLayout extends StatelessWidget {
  const ElectronicBalanceLayout({super.key});

  Future<void> _showAccountDialog(
    BuildContext context, [
    ElectronicBalanceAccount? account,
  ]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BalanceAccountDialog(account: account),
    );
  }

  Future<void> _showPurchaseDialog(
    BuildContext context,
    ElectronicBalanceAccount account,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BalancePurchaseDialog(account: account),
    );
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
                ? _EmptyBalanceState(
                    onCreate: () => _showAccountDialog(context),
                  )
                : ListView.separated(
                    itemCount: provider.accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final account = provider.accounts[index];
                      return _BalanceAccountCard(
                        account: account,
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

    final removed =
        context.read<ElectronicBalanceProvider>().removeAccount(account.id);
    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede eliminar una compañía con movimientos registrados.',
          ),
        ),
      );
    }
  }
}

class _BalanceAccountCard extends StatelessWidget {
  final ElectronicBalanceAccount account;
  final double sold;
  final double profit;
  final VoidCallback onPurchase;
  final VoidCallback onSale;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BalanceAccountCard({
    required this.account,
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
                  child: const Icon(
                    Icons.sim_card_outlined,
                    color: AppColors.primary,
                  ),
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
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _BalanceMetric(
                  label: 'Disponible',
                  value: account.balance,
                  emphasize: true,
                ),
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
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
          const Icon(
            Icons.sim_card_outlined,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 10),
          const Text(
            'No hay compañías de saldo registradas',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
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

class _BalanceAccountDialog extends StatefulWidget {
  final ElectronicBalanceAccount? account;

  const _BalanceAccountDialog({required this.account});

  @override
  State<_BalanceAccountDialog> createState() => _BalanceAccountDialogState();
}

class _BalanceAccountDialogState extends State<_BalanceAccountDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _rateController;
  late final TextEditingController _saldoController;
  late final TextEditingController _internetController;
  late final TextEditingController _llamadaController;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.companyName ?? '');
    _rateController = TextEditingController(
      text: account == null ? '' : _formatNumber(account.commissionRate),
    );
    _saldoController = TextEditingController(
      text: _formatAmounts(account?.amountsForCategory('Saldo') ?? const []),
    );
    _internetController = TextEditingController(
      text: _formatAmounts(account?.amountsForCategory('Internet') ?? const []),
    );
    _llamadaController = TextEditingController(
      text: _formatAmounts(account?.amountsForCategory('Llamada') ?? const []),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    _saldoController.dispose();
    _internetController.dispose();
    _llamadaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.account == null ? 'Agregar compañía' : 'Editar compañía',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Compañía',
                  hintText: 'Ej. Tigo',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Comisión (%)',
                  hintText: 'Ej. 5',
                  suffixText: '%',
                  prefixIcon: Icon(Icons.percent_outlined),
                ),
              ),
              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Montos de venta',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Escribe los montos separados por comas. Cada compañía puede tener sus propios montos.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _AmountsField(
                controller: _saldoController,
                label: 'Saldo',
                hint: 'Ej. 1.50, 2.50, 5, 10, 20, 40',
              ),
              const SizedBox(height: 10),
              _AmountsField(
                controller: _internetController,
                label: 'Internet',
                hint: 'Ej. 1.50, 2.50, 4, 8, 13, 15',
              ),
              const SizedBox(height: 10),
              _AmountsField(
                controller: _llamadaController,
                label: 'Llamada',
                hint: 'Ej. 1.50, 2.50, 5, 10',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.account == null ? 'Agregar' : 'Guardar'),
        ),
      ],
    );
  }

  void _save() {
    final rate = double.tryParse(_rateController.text.replaceAll(',', '.'));
    if (rate == null) {
      _showError('Ingresa una comisión válida entre 0% y 100%.');
      return;
    }

    final options = <ElectronicBalanceSaleOption>[
      ..._parseAmounts('Saldo', _saldoController.text),
      ..._parseAmounts('Internet', _internetController.text),
      ..._parseAmounts('Llamada', _llamadaController.text),
    ];

    final provider = context.read<ElectronicBalanceProvider>();

    if (widget.account == null) {
      final ok = provider.addAccount(
        companyName: _nameController.text,
        commissionRate: rate,
      );
      if (!ok) {
        _showError(
          'Revisa el nombre y la comisión. El nombre de la compañía no puede repetirse.',
        );
        return;
      }

      final created = provider.accounts.last;
      provider.setSaleOptions(
        accountId: created.id,
        options: options,
      );
    } else {
      final ok = provider.updateAccount(
        id: widget.account!.id,
        companyName: _nameController.text,
        commissionRate: rate,
      );
      if (!ok) {
        _showError(
          'Revisa el nombre y la comisión. El nombre de la compañía no puede repetirse.',
        );
        return;
      }
      provider.setSaleOptions(
        accountId: widget.account!.id,
        options: options,
      );
    }

    Navigator.pop(context);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static List<ElectronicBalanceSaleOption> _parseAmounts(
    String category,
    String text,
  ) {
    final values = text
        .split(RegExp(r'[,;\n]+'))
        .map((value) => double.tryParse(value.trim().replaceAll(',', '.')))
        .whereType<double>()
        .where((value) => value > 0);

    return values
        .map(
          (amount) => ElectronicBalanceSaleOption(
            category: category,
            amount: amount,
          ),
        )
        .toList();
  }

  static String _formatAmounts(List<double> amounts) {
    return amounts.map(_formatNumber).join(', ');
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}

class _AmountsField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _AmountsField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.attach_money_outlined),
      ),
    );
  }
}

class _BalancePurchaseDialog extends StatefulWidget {
  final ElectronicBalanceAccount account;

  const _BalancePurchaseDialog({required this.account});

  @override
  State<_BalancePurchaseDialog> createState() => _BalancePurchaseDialogState();
}

class _BalancePurchaseDialogState extends State<_BalancePurchaseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final commission = account.commissionRate / 100;

    return AlertDialog(
      title: const Text('Comprar saldo'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.companyName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Comisión aplicada: ${account.commissionRate.toStringAsFixed(2)}%',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Saldo comprado',
                prefixText: '\$',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ejemplo: \$20 de saldo → costo real \$${(20 * (1 - commission)).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(
              _controller.text.replaceAll(',', '.'),
            );
            final ok = amount != null &&
                context.read<ElectronicBalanceProvider>().registerPurchase(
                      accountId: account.id,
                      amount: amount,
                    );
            if (!ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ingresa un monto válido mayor que cero.'),
                ),
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
  static const _categories = ['Saldo', 'Internet', 'Llamada'];

  String _category = 'Saldo';
  final Map<String, int> _selectedQuantities = {};
  final Map<String, TextEditingController> _quantityControllers = {};

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final options = account.amountsForCategory(_category);
    final selectedEntries = _selectedQuantities.entries
        .where((entry) => entry.key.startsWith('$_category|'))
        .toList();

    var total = 0.0;
    for (final entry in _selectedQuantities.entries) {
      final separator = entry.key.indexOf('|');
      if (separator < 0) continue;
      final amount =
          double.tryParse(entry.key.substring(separator + 1)) ?? 0;
      total += amount * entry.value;
    }

    final profit = total * account.commissionRate / 100;

    return AlertDialog(
      title: const Text('Vender saldo'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
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
                decoration: const InputDecoration(
                  labelText: 'Tipo de venta',
                ),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _category = value);
                },
              ),
              const SizedBox(height: 14),
              Text(
                'Selecciona uno o varios montos',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (options.isEmpty)
                const Text(
                  'No hay montos configurados para esta categoría. '
                  'Edítalos desde la compañía.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((amount) {
                    final key = _key(_category, amount);
                    final selected = _selectedQuantities.containsKey(key);
                    return FilterChip(
                      label: Text('\$${_formatAmount(amount)}'),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedQuantities[key] = 1;
                            _quantityControllers[key]?.dispose();
                            _quantityControllers[key] =
                                TextEditingController(text: '1');
                          } else {
                            _selectedQuantities.remove(key);
                            _quantityControllers.remove(key)?.dispose();
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              if (selectedEntries.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Cantidad por monto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...selectedEntries.map((entry) {
                  final amount = double.tryParse(
                        entry.key.substring(entry.key.indexOf('|') + 1),
                      ) ??
                      0;
                  final controller = _quantityControllers.putIfAbsent(
                    entry.key,
                    () => TextEditingController(
                      text: entry.value.toString(),
                    ),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '\$${_formatAmount(amount)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                              isDense: true,
                            ),
                            onChanged: (value) {
                              final quantity = int.tryParse(value);
                              if (quantity != null && quantity > 0) {
                                _selectedQuantities[entry.key] = quantity;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (total > 0) ...[
                const SizedBox(height: 12),
                const Divider(),
                Text('Total vendido: \$${total.toStringAsFixed(2)}'),
                Text('Cliente paga: \$${total.toStringAsFixed(2)}'),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: total <= 0
              ? null
              : () {
                  final sales = <ElectronicBalanceSale>[];
                  for (final entry in _selectedQuantities.entries) {
                    final separator = entry.key.indexOf('|');
                    if (separator < 0) continue;
                    final category = entry.key.substring(0, separator);
                    final amount = double.tryParse(
                          entry.key.substring(separator + 1),
                        ) ??
                        0;
                    final quantity = entry.value;
                    if (amount <= 0 || quantity <= 0) continue;

                    sales.add(
                      ElectronicBalanceSale(
                        amount: amount,
                        quantity: quantity,
                        category: category,
                      ),
                    );
                  }

                  final ok = context
                      .read<ElectronicBalanceProvider>()
                      .registerSales(
                        accountId: account.id,
                        sales: sales,
                      );
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo registrar la venta.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                },
          child: const Text('Registrar ventas'),
        ),
      ],
    );
  }

  String _key(String category, double amount) =>
      '$category|${amount.toStringAsFixed(4)}';

  static String _formatAmount(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}
