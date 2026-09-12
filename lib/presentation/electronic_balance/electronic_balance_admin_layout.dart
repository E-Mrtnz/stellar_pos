import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';

class ElectronicBalanceAdminLayout extends StatelessWidget {
  const ElectronicBalanceAdminLayout({super.key});

  Future<void> _edit(BuildContext context, [ElectronicBalanceAccount? account]) => showDialog<void>(context: context, builder: (_) => _AccountDialog(account: account));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ElectronicBalanceProvider>();
    return Padding(padding: const EdgeInsets.all(AppDimensions.pagePadding), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: Text('Saldo electrónico', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary))), FilledButton.icon(onPressed: () => _edit(context), icon: const Icon(Icons.add, size: 19), label: const Text('Agregar compañía'))]),
      const SizedBox(height: 12),
      Expanded(child: provider.accounts.isEmpty ? Center(child: OutlinedButton.icon(onPressed: () => _edit(context), icon: const Icon(Icons.add), label: const Text('Agregar compañía'))) : ListView.separated(
        itemCount: provider.accounts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) { final account = provider.accounts[index]; return _AccountCard(account: account, sold: provider.totalSold(account.id), profit: provider.totalProfit(account.id), onPurchase: () => _purchase(context, account), onHistory: () => _history(context, account), onEdit: () => _edit(context, account), onDelete: () => _delete(context, account)); },
      )),
    ]));
  }

  Future<void> _purchase(BuildContext context, ElectronicBalanceAccount account) => showDialog<void>(context: context, builder: (_) => _PurchaseDialog(account: account));
  Future<void> _history(BuildContext context, ElectronicBalanceAccount account) => showDialog<void>(context: context, builder: (_) => _HistoryDialog(account: account));

  Future<void> _delete(BuildContext context, ElectronicBalanceAccount account) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Eliminar compañía'), content: Text('¿Deseas eliminar ${account.companyName}?'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar'))]));
    if (confirmed != true || !context.mounted) return;
    final removed = context.read<ElectronicBalanceProvider>().removeAccount(account.id);
    if (!removed) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede eliminar una compañía con movimientos registrados.')));
  }
}

class _AccountCard extends StatelessWidget {
  final ElectronicBalanceAccount account; final double sold; final double profit; final VoidCallback onPurchase, onHistory, onEdit, onDelete;
  const _AccountCard({required this.account, required this.sold, required this.profit, required this.onPurchase, required this.onHistory, required this.onEdit, required this.onDelete});
  @override Widget build(BuildContext context) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius), side: const BorderSide(color: AppColors.border)), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
    Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), shape: BoxShape.circle), child: const Icon(Icons.sim_card_outlined, color: AppColors.primary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(account.companyName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)), Text('Comisión: ${account.commissionRate.toStringAsFixed(2)}%', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)), if (account.saleCategories.length > 3) Text('Opciones: ${account.saleCategories.skip(3).join(', ')}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted))])), IconButton(tooltip: 'Historial de ventas', onPressed: onHistory, icon: const Icon(Icons.receipt_long_outlined)), IconButton(tooltip: 'Editar compañía', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)), IconButton(tooltip: 'Eliminar compañía', onPressed: onDelete, icon: const Icon(Icons.delete_outline))]),
    const Divider(height: 24), Row(children: [_Metric('Disponible', account.balance, true), _Metric('Vendido', sold, false), _Metric('Ganancia', profit, false)]),
    const SizedBox(height: 14), SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onPurchase, icon: const Icon(Icons.add_card_outlined, size: 18), label: const Text('Comprar saldo'))),
  ])));
}

class _Metric extends StatelessWidget {
  final String label; final double value; final bool emphasize;
  const _Metric(this.label, this.value, this.emphasize);
  @override Widget build(BuildContext context) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), const SizedBox(height: 3), Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: emphasize ? 16 : 13, fontWeight: FontWeight.bold, color: emphasize ? AppColors.primary : AppColors.textPrimary))]));
}

class _CustomField {
  final TextEditingController name; final TextEditingController amounts;
  _CustomField({String category = '', String values = ''}) : name = TextEditingController(text: category), amounts = TextEditingController(text: values);
  void dispose() { name.dispose(); amounts.dispose(); }
}

class _AccountDialog extends StatefulWidget {
  final ElectronicBalanceAccount? account;
  const _AccountDialog({required this.account});
  @override State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  static const _standard = ['Saldo', 'Internet', 'Llamada'];
  late final TextEditingController _name, _rate, _saldo, _internet, _llamada;
  final List<_CustomField> _custom = [];

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.companyName ?? '');
    _rate = TextEditingController(text: a == null ? '' : _fmt(a.commissionRate));
    _saldo = TextEditingController(text: _amounts(a?.amountsForCategory('Saldo') ?? const []));
    _internet = TextEditingController(text: _amounts(a?.amountsForCategory('Internet') ?? const []));
    _llamada = TextEditingController(text: _amounts(a?.amountsForCategory('Llamada') ?? const []));
    if (a != null) {
      final names = <String>[];
      for (final option in a.saleOptions) {
        final name = option.category.trim();
        if (name.isEmpty || _standard.contains(name) || names.contains(name)) continue;
        names.add(name);
      }
      for (final name in names) _custom.add(_CustomField(category: name, values: _amounts(a.amountsForCategory(name))));
    }
  }

  @override
  void dispose() { _name.dispose(); _rate.dispose(); _saldo.dispose(); _internet.dispose(); _llamada.dispose(); for (final f in _custom) f.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.account == null ? 'Agregar compañía' : 'Editar compañía'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Compañía', hintText: 'Ej. Tigo', prefixIcon: Icon(Icons.business_outlined))),
      const SizedBox(height: 12),
      TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Comisión (%)', suffixText: '%', prefixIcon: Icon(Icons.percent_outlined))),
      const SizedBox(height: 18),
      const Align(alignment: Alignment.centerLeft, child: Text('Montos de venta', style: TextStyle(fontWeight: FontWeight.bold))),
      const SizedBox(height: 6),
      const Align(alignment: Alignment.centerLeft, child: Text('Los montos se separan por comas. Las categorías personalizadas aparecen después de Saldo, Internet y Llamada.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      const SizedBox(height: 12),
      _AmountsField(_saldo, 'Saldo'), const SizedBox(height: 10),
      _AmountsField(_internet, 'Internet'), const SizedBox(height: 10),
      _AmountsField(_llamada, 'Llamada'), const SizedBox(height: 14),
      ..._custom.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _CustomFieldView(index: entry.key, field: entry.value, onRemove: () => setState(() { final f = _custom.removeAt(entry.key); f.dispose(); })))),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => setState(() => _custom.add(_CustomField())), icon: const Icon(Icons.add, size: 18), label: const Text('Agregar otra categoría'))),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: _save, child: Text(widget.account == null ? 'Agregar' : 'Guardar'))],
  );

  void _save() {
    final name = _name.text.trim();
    final rate = double.tryParse(_rate.text.replaceAll(',', '.'));
    if (name.isEmpty || rate == null || rate < 0 || rate > 100) { _error('Ingresa una compañía y una comisión válida entre 0% y 100%.'); return; }
    final options = <ElectronicBalanceSaleOption>[..._parse('Saldo', _saldo.text), ..._parse('Internet', _internet.text), ..._parse('Llamada', _llamada.text)];
    final names = <String>{};
    for (final field in _custom) {
      final category = field.name.text.trim();
      if (category.isEmpty || _standard.any((s) => s.toLowerCase() == category.toLowerCase())) { _error('Revisa los nombres de las categorías personalizadas.'); return; }
      if (!names.add(category.toLowerCase())) { _error('No puedes repetir una categoría personalizada.'); return; }
      final parsed = _parse(category, field.amounts.text);
      if (parsed.isEmpty) { _error('Agrega al menos un monto para "$category".'); return; }
      options.addAll(parsed);
    }
    final provider = context.read<ElectronicBalanceProvider>();
    if (widget.account == null) {
      if (!provider.addAccount(companyName: name, commissionRate: rate)) { _error('No se pudo agregar la compañía.'); return; }
      final created = provider.accounts.firstWhere((a) => a.companyName.toLowerCase() == name.toLowerCase());
      provider.setSaleOptions(accountId: created.id, options: options);
    } else {
      if (!provider.updateAccount(id: widget.account!.id, companyName: name, commissionRate: rate)) { _error('No se pudo actualizar la compañía.'); return; }
      provider.setSaleOptions(accountId: widget.account!.id, options: options);
    }
    Navigator.pop(context);
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  static List<ElectronicBalanceSaleOption> _parse(String category, String text) => text.split(RegExp(r'[,;\n]+')).map((v) => double.tryParse(v.trim().replaceAll(',', '.'))).whereType<double>().where((v) => v > 0).map((v) => ElectronicBalanceSaleOption(category: category, amount: v)).toList();
  static String _amounts(List<double> values) => values.map(_fmt).join(', ');
  static String _fmt(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
}

class _AmountsField extends StatelessWidget {
  final TextEditingController controller; final String label;
  const _AmountsField(this.controller, this.label);
  @override Widget build(BuildContext context) => TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label, hintText: 'Ej. 1.50, 2.50, 5, 10'));
}

class _CustomFieldView extends StatelessWidget {
  final int index; final _CustomField field; final VoidCallback onRemove;
  const _CustomFieldView({required this.index, required this.field, required this.onRemove});
  @override Widget build(BuildContext context) => Row(children: [Expanded(child: TextField(controller: field.name, decoration: const InputDecoration(labelText: 'Categoría personalizada'))), const SizedBox(width: 8), Expanded(child: TextField(controller: field.amounts, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Montos separados por comas'))), IconButton(tooltip: 'Eliminar categoría', onPressed: onRemove, icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed))]);
}

class _PurchaseDialog extends StatefulWidget {
  final ElectronicBalanceAccount account;
  const _PurchaseDialog({required this.account});
  @override State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  final _controller = TextEditingController();
  @override void dispose() { _controller.dispose(); super.dispose(); }
  void _save() { final amount = double.tryParse(_controller.text.replaceAll(',', '.')); if (amount == null || amount <= 0) return; if (context.read<ElectronicBalanceProvider>().registerPurchase(accountId: widget.account.id, amount: amount)) Navigator.pop(context); }
  @override Widget build(BuildContext context) => AlertDialog(title: Text('Comprar saldo · ${widget.account.companyName}'), content: TextField(controller: _controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: _save, child: const Text('Comprar'))]);
}

class _HistoryDialog extends StatelessWidget {
  final ElectronicBalanceAccount account;
  const _HistoryDialog({required this.account});
  @override Widget build(BuildContext context) { final transactions = context.watch<ElectronicBalanceProvider>().transactionsFor(account.id); return AlertDialog(title: Text('Historial · ${account.companyName}'), content: SizedBox(width: 520, height: 360, child: transactions.isEmpty ? const Center(child: Text('No hay movimientos registrados.')) : ListView.separated(itemCount: transactions.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, index) { final t = transactions[index]; return ListTile(dense: true, title: Text('${t.category} · \$${t.amount.toStringAsFixed(2)}'), subtitle: Text('${t.createdAt.day.toString().padLeft(2, '0')}/${t.createdAt.month.toString().padLeft(2, '0')}/${t.createdAt.year} · Ganancia \$${t.profit.toStringAsFixed(2)}')); })), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]); }
}
