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

  ElectronicBalanceCartItem copyWith({int? quantity}) => ElectronicBalanceCartItem(
        accountId: accountId,
        companyName: companyName,
        category: category,
        amount: amount,
        quantity: quantity ?? this.quantity,
      );
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
  State<ElectronicBalanceSaleDialog> createState() => _ElectronicBalanceSaleDialogState();
}

class _ElectronicBalanceSaleDialogState extends State<ElectronicBalanceSaleDialog> {
  final Map<String, ElectronicBalanceCartItem> _selected = {};
  late final List<ElectronicBalanceCartItem> _initialSelection;
  String? _accountId;
  String _category = 'Saldo';

  static const _categories = ['Saldo', 'Internet', 'Llamada'];

  @override
  void initState() {
    super.initState();
    _initialSelection = List<ElectronicBalanceCartItem>.from(widget.initialSelection);
    for (final item in _initialSelection) _selected[item.key] = item;
    if (_initialSelection.isNotEmpty) {
      _accountId = _initialSelection.first.accountId;
      _category = _initialSelection.first.category;
    }
  }

  void _publishSelection() => widget.onSelectionChanged(List.unmodifiable(_selected.values));

  void _restoreInitialSelection() => widget.onSelectionChanged(List<ElectronicBalanceCartItem>.from(_initialSelection));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ElectronicBalanceProvider>();
    final accounts = provider.accounts;
    final selectedAccount = _accountId == null ? null : provider.findAccount(_accountId!);
    final options = selectedAccount?.amountsForCategory(_category) ?? const <double>[];

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 690),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 15),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Venta de saldo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text('Selecciona la compañía, tipo y denominación', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(tooltip: 'Cerrar', onPressed: () { _restoreInitialSelection(); Navigator.pop(context); }, icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: accounts.isEmpty
                  ? const _EmptyBalanceCompanies()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionLabel(icon: Icons.business_outlined, label: 'Compañía'),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 9,
                            runSpacing: 9,
                            children: accounts.map((account) => _ChoiceChip(
                              label: account.companyName,
                              icon: Icons.sim_card_outlined,
                              selected: account.id == _accountId,
                              onTap: () => setState(() => _accountId = account.id),
                            )).toList(),
                          ),
                          if (selectedAccount != null) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                              child: Row(
                                children: [
                                  Expanded(child: Text(selectedAccount.companyName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                                  Text('Disponible: \$${selectedAccount.balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _SectionLabel(icon: Icons.tune_rounded, label: 'Tipo de recarga'),
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 9,
                              runSpacing: 9,
                              children: _categories.map((category) => _ChoiceChip(
                                label: category,
                                selected: _category == category,
                                onTap: () => setState(() => _category = category),
                              )).toList(),
                            ),
                            const SizedBox(height: 20),
                            const _SectionLabel(icon: Icons.payments_outlined, label: 'Denominación'),
                            const SizedBox(height: 9),
                            if (options.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                                child: const Text('No hay montos configurados para esta categoría.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              )
                            else
                              LayoutBuilder(
                                builder: (_, constraints) {
                                  final columns = constraints.maxWidth >= 620 ? 5 : constraints.maxWidth >= 430 ? 4 : 3;
                                  final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: options.map((amount) {
                                      final key = '${selectedAccount.id}|$_category|${amount.toStringAsFixed(4)}';
                                      final item = _selected[key];
                                      return _AmountTile(
                                        width: width,
                                        amount: amount,
                                        quantity: item?.quantity ?? 0,
                                        onTap: () => _increment(selectedAccount, _category, amount),
                                        onLongPress: item == null ? null : () => _remove(key),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  if (_selected.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(color: AppColors.primary.withAlpha(12), borderRadius: BorderRadius.circular(9)),
                      child: Text('${_selected.values.fold<int>(0, (sum, item) => sum + item.quantity)} recarga(s) seleccionada(s)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () { _restoreInitialSelection(); Navigator.pop(context); }, child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: _selected.isEmpty ? null : () => Navigator.pop(context), icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Listo')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _increment(ElectronicBalanceAccount account, String category, double amount) {
    final key = '${account.id}|$category|${amount.toStringAsFixed(4)}';
    final current = _selected[key];
    setState(() {
      _selected[key] = current == null
          ? ElectronicBalanceCartItem(accountId: account.id, companyName: account.companyName, category: category, amount: amount, quantity: 1)
          : current.copyWith(quantity: current.quantity + 1);
    });
    _publishSelection();
  }

  void _remove(String key) {
    setState(() => _selected.remove(key));
    _publishSelection();
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
        ],
      );
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip({required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withAlpha(15) : AppColors.inputBackground,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 17, color: selected ? AppColors.primary : AppColors.textSecondary), const SizedBox(width: 7)],
              Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.primary : AppColors.textPrimary)),
            ],
          ),
        ),
      );
}

class _AmountTile extends StatelessWidget {
  final double width;
  final double amount;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _AmountTile({required this.width, required this.amount, required this.quantity, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(15) : AppColors.inputBackground,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('\$${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: selected ? AppColors.primary : AppColors.textPrimary)),
            const SizedBox(height: 5),
            Text(selected ? '×$quantity' : 'Tocar para agregar', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? AppColors.primary : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _EmptyBalanceCompanies extends StatelessWidget {
  const _EmptyBalanceCompanies();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(45),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sim_card_outlined, size: 44, color: AppColors.textMuted),
              SizedBox(height: 10),
              Text('No hay compañías de saldo configuradas.', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              SizedBox(height: 4),
              Text('Créala desde la administración de saldo electrónico.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
}
