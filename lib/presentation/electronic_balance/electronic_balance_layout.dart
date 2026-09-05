import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';

class ElectronicBalanceLayout extends StatelessWidget {
  const ElectronicBalanceLayout({super.key});

  Future<void> _account(BuildContext context, [ElectronicBalanceAccount? account]) => showDialog<void>(
        context: context,
        builder: (_) => _BalanceAccountDialog(account: account),
      );

  Future<void> _purchase(BuildContext context, ElectronicBalanceAccount account) => showDialog<void>(
        context: context,
        builder: (_) => _BalancePurchaseDialog(account: account),
      );

  Future<void> _sale(BuildContext context, ElectronicBalanceAccount account) => showDialog<void>(
        context: context,
        builder: (_) => _BalanceSaleDialog(account: account),
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
                        onSale: () => _sale(context, account),
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
  final VoidCallback onSale;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BalanceAccountCard({required this.account, required this.sold, required this.profit, required this.onPurchase, required this.onSale, required this.onEdit, required this.onDelete});

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
              ])),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
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
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(onPressed: onSale, icon: const Icon(Icons.point_of_sale_outlined, size: 18), label: const Text('Vender saldo'))),
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

class _BalanceAccountDialog extends StatefulWidget {
  final ElectronicBalanceAccount? account;
  const _BalanceAccountDialog({required this.account});
  @override
  State<_BalanceAccountDialog> createState() => _BalanceAccountDialogState();
}

class _BalanceAccountDialogState extends State<_BalanceAccountDialog> {
  late final TextEditingController _name;
  late final TextEditingController _rate;
  late final TextEditingController _saldo;
  late final TextEditingController _internet;
  late final TextEditingController _llamada;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.companyName ?? '');
    _rate = TextEditingController(text: a == null ? '' : _format(a.commissionRate));
    _saldo = TextEditingController(text: _amounts(a?.amountsForCategory('Saldo') ?? const []));
    _internet = TextEditingController(text: _amounts(a?.amountsForCategory('Internet') ?? const []));
    _llamada = TextEditingController(text: _amounts(a?.amountsForCategory('Llamada') ?? const []));
  }

  @override
  void dispose() { _name.dispose(); _rate.dispose(); _saldo.dispose(); _internet.dispose(); _llamada.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.account == null ? 'Agregar compañía' : 'Editar compañía'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Compañía', hintText: 'Ej. Tigo', prefixIcon: Icon(Icons.business_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Comisión (%)', suffixText: '%', prefixIcon: Icon(Icons.percent_outlined))),
          const SizedBox(height: 18),
          const Align(alignment: Alignment.centerLeft, child: Text('Montos de venta', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(height: 6),
          const Align(alignment: Alignment.centerLeft, child: Text('Escribe los montos separados por comas.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          const SizedBox(height: 12),
          _AmountsField(controller: _saldo, label: 'Saldo', hint: 'Ej. 1.50, 2.50, 5, 10, 20, 40'),
          const SizedBox(height: 10),
          _AmountsField(controller: _internet, label: 'Internet', hint: 'Ej. 1.50, 2.50, 4, 8, 13, 15'),
          const SizedBox(height: 10),
          _AmountsField(controller: _llamada, label: 'Llamada', hint: 'Ej. 1.50, 2.50, 5, 10'),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: _save, child: Text(widget.account == null ? 'Agregar' : 'Guardar'))],
      );

  void _save() {
    final rate = double.tryParse(_rate.text.replaceAll(',', '.'));
    if (rate == null || rate < 0 || rate > 100 || _name.text.trim().isEmpty) { _error('Ingresa una compañía y una comisión válida entre 0% y 100%.'); return; }
    final options = <ElectronicBalanceSaleOption>[..._parse('Saldo', _saldo.text), ..._parse('Internet', _internet.text), ..._parse('Llamada', _llamada.text)];
    final provider = context.read<ElectronicBalanceProvider>();
    if (widget.account == null) {
      final ok = provider.addAccount(companyName: _name.text, commissionRate: rate);
      if (!ok) { _error('No se pudo agregar la compañía.'); return; }
      provider.setSaleOptions(accountId: provider.accounts.last.id, options: options);
    } else {
      final ok = provider.updateAccount(id: widget.account!.id, companyName: _name.text, commissionRate: rate);
      if (!ok) { _error('No se pudo actualizar la compañía.'); return; }
      provider.setSaleOptions(accountId: widget.account!.id, options: options);
    }
    Navigator.pop(context);
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  static List<ElectronicBalanceSaleOption> _parse(String category, String text) => text.split(RegExp(r'[,;\n]+')).map((v) => double.tryParse(v.trim().replaceAll(',', '.'))).whereType<double>().where((v) => v > 0).map((v) => ElectronicBalanceSaleOption(category: category, amount: v)).toList();
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

class _BalancePurchaseDialog extends StatefulWidget {
  final ElectronicBalanceAccount account;
  const _BalancePurchaseDialog({required this.account});
  @override
  State<_BalancePurchaseDialog> createState() => _BalancePurchaseDialogState();
}

class _BalancePurchaseDialogState extends State<_BalancePurchaseDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Comprar saldo'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.account.companyName, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Comisión aplicada: ${widget.account.commissionRate.toStringAsFixed(2)}%'),
          const SizedBox(height: 14),
          TextField(controller: _controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Saldo comprado', prefixText: '\$')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () {
          final amount = double.tryParse(_controller.text.replaceAll(',', '.'));
          final ok = amount != null && context.read<ElectronicBalanceProvider>().registerPurchase(accountId: widget.account.id, amount: amount);
          if (!ok) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un monto válido mayor que cero.'))); return; }
          Navigator.pop(context);
        }, child: const Text('Registrar compra'))],
      );
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
  final Map<String, int> _selected = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() { for (final c in _controllers.values) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final options = account.amountsForCategory(_category);
    double total = 0;
    for (final e in _selected.entries) { final i = e.key.indexOf('|'); if (i >= 0) total += (double.tryParse(e.key.substring(i + 1)) ?? 0) * e.value; }
    final profit = total * account.commissionRate / 100;
    final selectedEntries = _selected.entries.where((e) => e.key.startsWith('$_category|')).toList();

    return AlertDialog(
      title: const Text('Vender saldo'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${account.companyName} · Disponible: \$${account.balance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: 'Tipo de venta'), items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { if (v != null) setState(() => _category = v); }),
        const SizedBox(height: 14),
        const Text('Selecciona uno o varios montos', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (options.isEmpty) const Text('No hay montos configurados para esta categoría.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
        else Wrap(spacing: 8, runSpacing: 8, children: options.map((amount) {
          final key = _key(_category, amount); final selected = _selected.containsKey(key);
          return FilterChip(label: Text('\$${_formatAmount(amount)}'), selected: selected, onSelected: (value) { setState(() { if (value) { _selected[key] = 1; _controllers[key]?.dispose(); _controllers[key] = TextEditingController(text: '1'); } else { _selected.remove(key); _controllers.remove(key)?.dispose(); } }); });
        }).toList()),
        if (selectedEntries.isNotEmpty) ...[
          const SizedBox(height: 16), const Text('Cantidad por monto', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          ...selectedEntries.map((entry) {
            final amount = double.tryParse(entry.key.substring(entry.key.indexOf('|') + 1)) ?? 0;
            final controller = _controllers.putIfAbsent(entry.key, () => TextEditingController(text: '${entry.value}'));
            return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: Text('\$${_formatAmount(amount)}', style: const TextStyle(fontWeight: FontWeight.w600))), SizedBox(width: 90, child: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad', isDense: true), onChanged: (v) { final q = int.tryParse(v); if (q != null && q > 0) _selected[entry.key] = q; }))]));
          }),
        ],
        if (total > 0) ...[
          const SizedBox(height: 12), const Divider(),
          Text('Total vendido: \$${total.toStringAsFixed(2)}'),
          Text('Cliente paga: \$${total.toStringAsFixed(2)}'),
          Text('Ganancia: \$${profit.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold)),
        ],
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: total <= 0 ? null : _register, child: const Text('Registrar ventas'))],
    );
  }

  void _register() {
    final sales = <ElectronicBalanceSale>[];
    for (final e in _selected.entries) { final i = e.key.indexOf('|'); if (i < 0) continue; final amount = double.tryParse(e.key.substring(i + 1)) ?? 0; if (amount > 0 && e.value > 0) sales.add(ElectronicBalanceSale(amount: amount, quantity: e.value, category: e.key.substring(0, i))); }
    final ok = context.read<ElectronicBalanceProvider>().registerSales(accountId: widget.account.id, sales: sales);
    if (!ok) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo registrar la venta.'))); return; }
    Navigator.pop(context);
  }

  String _key(String category, double amount) => '$category|${amount.toStringAsFixed(4)}';
  static String _formatAmount(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
