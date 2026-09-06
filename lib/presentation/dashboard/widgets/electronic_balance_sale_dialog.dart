import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';

class ElectronicBalanceCartItem {
  final String accountId;
  final String companyName;
  final String category;
  final double amount;
  final int quantity;

  const ElectronicBalanceCartItem({
    required this.accountId,
    required this.companyName,
    required this.category,
    required this.amount,
    required this.quantity,
  });

  String get key => '$accountId|$category|${amount.toStringAsFixed(4)}';

  ElectronicBalanceCartItem copyWith({int? quantity}) {
    return ElectronicBalanceCartItem(
      accountId: accountId,
      companyName: companyName,
      category: category,
      amount: amount,
      quantity: quantity ?? this.quantity,
    );
  }
}

class ElectronicBalanceSaleDialog extends StatefulWidget {
  final List<ElectronicBalanceCartItem> initialSelection;
  final ValueChanged<List<ElectronicBalanceCartItem>> onSelectionChanged;

  const ElectronicBalanceSaleDialog({
    super.key,
    required this.initialSelection,
    required this.onSelectionChanged,
  });

  @override
  State<ElectronicBalanceSaleDialog> createState() =>
      _ElectronicBalanceSaleDialogState();
}

class _ElectronicBalanceSaleDialogState
    extends State<ElectronicBalanceSaleDialog> {
  final Map<String, ElectronicBalanceCartItem> _selected = {};
  late final List<ElectronicBalanceCartItem> _initialSelection;
  String? _accountId;
  String _category = 'Saldo';

  static const _categories = ['Saldo', 'Internet', 'Llamada'];

  @override
  void initState() {
    super.initState();
    _initialSelection = List<ElectronicBalanceCartItem>.from(
      widget.initialSelection,
    );
    for (final item in _initialSelection) {
      _selected[item.key] = item;
    }
  }

  void _publishSelection() {
    widget.onSelectionChanged(_selected.values.toList());
  }

  void _restoreInitialSelection() {
    widget.onSelectionChanged(List<ElectronicBalanceCartItem>.from(_initialSelection));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ElectronicBalanceProvider>();
    final accounts = provider.accounts;
    final selectedAccount = _accountId == null
        ? null
        : provider.findAccount(_accountId!);
    final options = selectedAccount?.amountsForCategory(_category) ??
        const <double>[];
    final selectedForCategory = _selected.values.where(
      (item) => item.accountId == _accountId && item.category == _category,
    );
    final selectedTotal = _selected.values.fold<double>(
      0,
      (sum, item) => sum + item.amount * item.quantity,
    );

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 18, 14, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.phone_android_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Venta de saldo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () {
              _restoreInitialSelection();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: accounts.isEmpty
            ? const _EmptyBalanceCompanies()
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compañía',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: accounts.map((account) {
                        final selected = account.id == _accountId;
                        return _ChoiceChip(
                          label: account.companyName,
                          icon: Icons.sim_card_outlined,
                          selected: selected,
                          onTap: () => setState(() => _accountId = account.id),
                        );
                      }).toList(),
                    ),
                    if (selectedAccount != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedAccount.companyName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              'Disponible: \$${selectedAccount.balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Tipo de recarga',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _categories.map((category) {
                          return _ChoiceChip(
                            label: category,
                            selected: _category == category,
                            onTap: () => setState(() => _category = category),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Denominaciones',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (options.isEmpty)
                        const Text(
                          'No hay montos configurados para esta categoría.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: options.map((amount) {
                            final key =
                                '${selectedAccount.id}|$_category|${amount.toStringAsFixed(4)}';
                            final item = _selected[key];
                            return _AmountTile(
                              amount: amount,
                              quantity: item?.quantity ?? 0,
                              onTap: () => _increment(
                                selectedAccount,
                                _category,
                                amount,
                              ),
                              onLongPress: item == null
                                  ? null
                                  : () => _remove(key),
                            );
                          }).toList(),
                        ),
                      if (selectedForCategory.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Seleccionado en esta categoría',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...selectedForCategory.map(
                          (item) => _SelectedLine(item: item),
                        ),
                      ],
                    ],
                    if (_selected.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(50),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Total de recargas seleccionadas',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '\$${selectedTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _restoreInitialSelection();
            Navigator.pop(context);
          },
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Listo'),
        ),
      ],
    );
  }

  void _increment(
    ElectronicBalanceAccount account,
    String category,
    double amount,
  ) {
    final key = '${account.id}|$category|${amount.toStringAsFixed(4)}';
    final current = _selected[key];
    setState(() {
      _selected[key] = current == null
          ? ElectronicBalanceCartItem(
              accountId: account.id,
              companyName: account.companyName,
              category: category,
              amount: amount,
              quantity: 1,
            )
          : current.copyWith(quantity: current.quantity + 1);
    });
    _publishSelection();
  }

  void _remove(String key) {
    setState(() => _selected.remove(key));
    _publishSelection();
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withAlpha(15)
              : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 17,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  final double amount;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _AmountTile({
    required this.amount,
    required this.quantity,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 92,
        height: 68,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withAlpha(15)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\$${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              selected ? '×$quantity' : 'Tocar para agregar',
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedLine extends StatelessWidget {
  final ElectronicBalanceCartItem item;
  const _SelectedLine({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item.companyName} · ${item.category} · \$${item.amount.toStringAsFixed(item.amount == item.amount.roundToDouble() ? 0 : 2)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
            ),
          ),
          Text(
            '×${item.quantity}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _EmptyBalanceCompanies extends StatelessWidget {
  const _EmptyBalanceCompanies();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sim_card_outlined, size: 42, color: AppColors.textMuted),
            SizedBox(height: 10),
            Text(
              'No hay compañías de saldo configuradas.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 4),
            Text(
              'Créala desde la administración de saldo electrónico.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
