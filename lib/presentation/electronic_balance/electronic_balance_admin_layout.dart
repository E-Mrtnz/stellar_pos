import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';

class ElectronicBalanceAdminLayout extends StatelessWidget {
  const ElectronicBalanceAdminLayout({super.key});

  Future<void> _account(BuildContext context, [ElectronicBalanceAccount? account]) => showDialog<void>(
        context: context,
        builder: (_) => _BalanceAccountDialog(account: account),
      );

  Future<void> _purchase(BuildContext context, ElectronicBalanceAccount account) => showDialog<void>(
        context: context,
        builder: (_) => _BalancePurchaseDialog(account: account),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ElectronicBalanceProvider>();
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Text('Saldo electrónico', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
            FilledButton.icon(onPressed: () => _account(context), icon: const Icon(Icons.add, size: 19), label: const Text('Agregar compañía')),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: provider.accounts.isEmpty
                ? _EmptyBalanceState(onCreate: () => _account(context))
                : ListView.separated(
                    itemCount: provider.accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final account = provider.accounts[index];
                      return _BalanceAccountCard(
                        account: account,
                        sold: provider.totalSold(account.id),
                        profit: provider.totalProfit(account.id),
                        onPurchase: () => _purchase(context, account),
                        onHistory: () => _history(context, account),
                        onEdit: () => _account(context, account),
                        onDelete: () => _delete(context, account),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _history(BuildContext context, ElectronicBalanceAccount account) => showDialog<void>(
        context: context,
        builder: (_) => _BalanceSalesHistoryDialog(account: account),
      );

  Future<void> _delete(BuildContext context, ElectronicBalanceAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar compañía'),
        content: Text('¿Deseas eliminar ${account.companyName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed = context.read<ElectronicBalanceProvider>().removeAccount(account.id);
    if (!removed) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede eliminar una compañía con movimientos registrados.')));
  }
}

class _BalanceAccountCard extends StatelessWidget {
  final ElectronicBalanceAccount account;
  final double sold;
  final double profit;
  final VoidCallback onPurchase;
  final VoidCallback onHistory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BalanceAccountCard({required this.account, required this.sold, required this.profit, required this.onPurchase, required this.onHistory, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius), side: const BorderSide(color: AppColors.border)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), shape: BoxShape.circle), child: const Icon(Icons.sim_card_outlined, color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(account.companyName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text('Comisión: ${account.commissionRate.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (account.saleCategories.length > 3)
                  Text('Opciones: ${account.saleCategories.skip(3).join(', ')}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ])),
              IconButton(tooltip: 'Historial de ventas', onPressed: onHistory, icon: const Icon(Icons.receipt_long_outlined)),
              IconButton(tooltip: 'Editar compañía', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
              IconButton(tooltip: 'Eliminar compañía', onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
            ]),
            const Divider(height: 24),
            Row(children: [
              _BalanceMetric(label: 'Disponible', value: account.balance, emphasize: true),
              _BalanceMetric(label: 'Vendido', value: sold),
              _BalanceMetric(label: 'Ganancia', value: profit),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: onPurchase, icon: const Icon(Icons.add_card_outlined, size: 18), label: const Text('Comprar saldo'))),
            ]),
          ]),
        ),
      );
}

class _BalanceMetric extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasize;
  const _BalanceMetric({required this.label, required this.value, this.emphasize = false});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: emphasize ? 16 : 13, fontWeight: FontWeight.bold, color: emphasize ? AppColors.primary : AppColors.textPrimary)),
        ]),
      );
}

class _EmptyBalanceState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyBalanceState({required this.onCreate});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.sim_card_outlined, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 10),
        const Text('No hay compañías de saldo registradas', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Agregar compañía')),
      ]));
}

class _CustomSaleField {
  final TextEditingController name;
  final TextEditingController amounts;
  _CustomSaleField({String category = '', String values = ''})
      : name = TextEditingController(text: category),
        amounts = TextEditingController(text: values);

  void dispose() {
    name.dispose();
    amounts.dispose();
  }
}

class _BalanceAccountDialog extends StatefulWidget {
  final ElectronicBalanceAccount? account;
  const _BalanceAccountDialog({required this.account});
  @override
  State<_BalanceAccountDialog> createState() => _BalanceAccountDialogState();
}

class _BalanceAccountDialogState extends State<_BalanceAccountDialog> {
  static const _standardCategories = ['Saldo', 'Internet', 'Llamada'];
  late final TextEditingController _name;
  late final TextEditingController _rate;
  late final TextEditingController _saldo;
  late final TextEditingController _internet;
  late final TextEditingController _llamada;
  final List<_CustomSaleField> _customFields = [];

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.companyName ?? '');
    _rate = TextEditingController(text: a == null ? '' : _format(a.commissionRate));
    _saldo = TextEditingController(text: _amounts(a?.amountsForCategory('Saldo') ?? const []));
    _internet = TextEditingController(text: _amounts(a?.amountsForCategory('Internet') ?? const []));
    _llamada = TextEditingController(text: _amounts(a?.amountsForCategory('Llamada') ?? const []));

    if (a != null) {
      final customCategories = <String>[];
      for (final option in a.saleOptions) {
        final category = option.category.trim();
        if (category.isEmpty || _standardCategories.contains(category) || customCategories.contains(category)) continue;
        customCategories.add(category);
      }
      for (final category in customCategories) {
        final values = a.amountsForCategory(category);
        _customFields.add(_CustomSaleField(category: category, values: _amounts(values)));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _saldo.dispose();
    _internet.dispose();
    _llamada.dispose();
    for (final field in _customFields) field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.account == null ? 'Agregar compañía' : 'Editar compañía'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Compañía', hintText: 'Ej. Tigo', prefixIcon: Icon(Icons.business_outlined))),
              const SizedBox(height: 12),
              TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Comisión (%)', suffixText: '%', prefixIcon: Icon(Icons.percent_outlined))),
              const SizedBox(height: 18),
              const Align(alignment: Alignment.centerLeft, child: Text('Montos de venta', style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 6),
              const Align(alignment: Alignment.centerLeft, child: Text('Los tres campos base son fijos. Puedes agregar otras categorías propias de esta compañía y sus montos separados por comas.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              const SizedBox(height: 12),
              _AmountsField(controller: _saldo, label: 'Saldo', hint: 'Ej. 1.50, 2.50, 5, 10, 20, 40'),
              const SizedBox(height: 10),
              _AmountsField(controller: _internet, label: 'Internet', hint: 'Ej. 1.50, 2.50, 4, 8, 13, 15'),
              const SizedBox(height: 10),
              _AmountsField(controller: _llamada, label: 'Llamada', hint: 'Ej. 1.50, 2.50, 5, 10'),
              const SizedBox(height: 14),
              ..._customFields.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CustomAmountsField(
                      index: entry.key,
                      field: entry.value,
                      onRemove: () => setState(() {
                        final field = _customFields.removeAt(entry.key);
                        field.dispose();
                      }),
                    ),
                  )),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _customFields.add(_CustomSaleField())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar otra categoría'),
                ),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _save, child: Text(widget.account == null ? 'Agregar' : 'Guardar')),
        ],
      );

  void _save() {
    final rate = double.tryParse(_rate.text.replaceAll(',', '.'));
    final companyName = _name.text.trim();
    if (rate == null || rate < 0 || rate > 100 || companyName.isEmpty) {
      _error('Ingresa una compañía y una comisión válida entre 0% y 100%.');
      return;
    }

    final options = <ElectronicBalanceSaleOption>[
      ..._parse('Saldo', _saldo.text),
      ..._parse('Internet', _internet.text),
      ..._parse('Llamada', _llamada.text),
    ];
    final customNames = <String>{};
    for (final field in _customFields) {
      final category = field.name.text.trim();
      if (category.isEmpty) {
        _error('Todas las categorías personalizadas deben tener un nombre.');
        return;
      }
      if (_standardCategories.any((value) => value.toLowerCase() == category.toLowerCase())) {
        _error('Una categoría personalizada no puede llamarse Saldo, Internet o Llamada.');
        return;
      }
      final normalized = category.toLowerCase();
      if (!customNames.add(normalized)) {
        _error('No puedes repetir el nombre de una categoría personalizada.');
        return;
      }
      final values = _parse(category, field.amounts.text);
      if (values.isEmpty) {
        _error('Agrega al menos un monto para "$category".');
        return;
      }
      options.addAll(values);
    }

    final provider = context.read<ElectronicBalanceProvider>();
    if (widget.account == null) {
      final ok = provider.addAccount(companyName: companyName, commissionRate: rate);
      if (!ok) {
        _error('No se pudo agregar la compañía. Verifica que no exista otra con el mismo nombre.');
        return;
      }
      final created = provider.accounts.firstWhere((account) => account.companyName.toLowerCase() == companyName.toLowerCase());
      provider.setSaleOptions(accountId: created.id, options: options);
    } else {
      final ok = provider.updateAccount(id: widget.account!.id, companyName: companyName, commissionRate: rate);
      if (!ok) {
        _error('No se pudo actualizar la compañía. Verifica que no exista otra con el mismo nombre.');
        return;
      }
      provider.setSaleOptions(accountId: widget.account!.id, options: options);
    }
    Navigator.pop(context);
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  static List<ElectronicBalanceSaleOption> _parse(String category, String text) => text
      .split(RegExp(r'[,;\n]+'))
      .map((v) => double.tryParse(v.trim().replaceAll(',', '.')))
      .whereType<double>()
      .where((v) => v > 0)
      .map((v) => ElectronicBalanceSaleOption(category: category, amount: v))
      .toList();

  static String _amounts(List<double> values) => values.map(_format).join(', ');
  static String _format(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

class _AmountsField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _AmountsField({required this.controller, required this.label, required this.hint});
  @override
  Widget build(BuildContext context) => TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label, hintText: hint));
}

class _CustomAmountsField extends StatelessWidget {
  final int index;
  final _CustomSaleField field;
  final VoidCallback onRemove;
  const _CustomAmountsField({required this.index, required this.field, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text('Categoría personalizada ${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
            IconButton(tooltip: 'Quitar categoría', visualDensity: VisualDensity.compact, onPressed: onRemove, icon: const Icon(Icons.delete_outline, size: 18)),
          ]),
          TextField(controller: field.name, decoration: const InputDecoration(labelText: 'Nombre de la categoría', hintText: 'Ej. Súper paquetes')),
          const SizedBox(height: 8),
          TextField(controller: field.amounts, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Montos', hintText: 'Ej. 3, 5, 10, 15')),
        ]),
      );
}

class _BalancePurchaseDialog extends StatefulWidget {
  final ElectronicBalanceAccount account;
  const _BalancePurchaseDialog({required this.account});
  @override
  State<_BalancePurchaseDialog> createState() => _BalancePurchaseDialogState();
}

class _BalancePurchaseDialogState extends State<_BalancePurchaseDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Comprar saldo'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.account.companyName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Comisión aplicada: ${widget.account.commissionRate.toStringAsFixed(2)}%'),
          const SizedBox(height: 14),
          TextField(controller: _controller, focusNode: _focusNode, autofocus: false, keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.done, decoration: const InputDecoration(labelText: 'Saldo comprado', prefixText: '\$')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final amount = double.tryParse(_controller.text.replaceAll(',', '.'));
            final ok = amount != null && context.read<ElectronicBalanceProvider>().registerPurchase(accountId: widget.account.id, amount: amount);
            if (!ok) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un monto válido mayor que cero.'))); return; }
            Navigator.pop(context);
          }, child: const Text('Registrar compra')),
        ],
      );
}

class _BalanceSalesHistoryDialog extends StatelessWidget {
  final ElectronicBalanceAccount account;
  const _BalanceSalesHistoryDialog({required this.account});

  @override
  Widget build(BuildContext context) {
    final transactions = context
        .watch<ElectronicBalanceProvider>()
        .transactionsFor(account.id)
        .where((t) => t.type == ElectronicBalanceTransactionType.sale)
        .toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Historial de ventas de saldo', style: AppTextStyles.sectionTitle),
                Text(account.companyName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 12),
            if (transactions.isEmpty)
              const Expanded(child: Center(child: Text('No hay ventas de saldo registradas.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))))
            else
              Expanded(child: Container(
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final transaction = transactions[index];
                    final date = '${transaction.createdAt.day.toString().padLeft(2, '0')}/${transaction.createdAt.month.toString().padLeft(2, '0')}/${transaction.createdAt.year}';
                    final time = '${transaction.createdAt.hour.toString().padLeft(2, '0')}:${transaction.createdAt.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      dense: true,
                      title: Text('${transaction.category} · \$${transaction.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      subtitle: Text('$date $time · Ganancia \$${transaction.profit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    );
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
