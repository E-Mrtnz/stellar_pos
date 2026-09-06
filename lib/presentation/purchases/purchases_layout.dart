import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/purchases_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';

class PurchasesLayout extends StatefulWidget {
  const PurchasesLayout({super.key});
  @override
  State<PurchasesLayout> createState() => _PurchasesLayoutState();
}

enum _Period { daily, weekly, monthly, yearly, custom }

class _PurchasesLayoutState extends State<PurchasesLayout> {
  final _searchController = TextEditingController();
  String _query = '';
  _Period _period = _Period.monthly;
  DateTime _anchor = DateTime.now();
  DateTimeRange? _customRange;

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  DateTimeRange get _range {
    if (_period == _Period.custom && _customRange != null) {
      return DateTimeRange(
        start: DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day),
        end: DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59, 999),
      );
    }
    final day = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case _Period.daily:
        return DateTimeRange(start: day, end: DateTime(day.year, day.month, day.day, 23, 59, 59, 999));
      case _Period.weekly:
        final start = day.subtract(Duration(days: day.weekday - DateTime.monday));
        return DateTimeRange(start: start, end: DateTime(start.year, start.month, start.day + 6, 23, 59, 59, 999));
      case _Period.monthly:
        return DateTimeRange(start: DateTime(day.year, day.month), end: DateTime(day.year, day.month + 1, 0, 23, 59, 59, 999));
      case _Period.yearly:
        return DateTimeRange(start: DateTime(day.year), end: DateTime(day.year + 1, 1, 0, 23, 59, 59, 999));
      case _Period.custom:
        return DateTimeRange(start: DateTime(day.year, day.month), end: DateTime(day.year, day.month + 1, 0, 23, 59, 59, 999));
    }
  }

  List<PurchaseRecord> _purchases(PurchasesProvider provider) {
    final r = _range;
    final q = _query.trim().toLowerCase();
    final list = provider.purchases.where((p) {
      if (p.arrivalAt.isBefore(r.start) || p.arrivalAt.isAfter(r.end)) return false;
      if (q.isEmpty) return true;
      return p.distributorName.toLowerCase().contains(q) || p.invoiceNumber.toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) => b.arrivalAt.compareTo(a.arrivalAt));
    return list;
  }

  List<SaleRecord> _sales(SalesProvider provider) {
    final r = _range;
    return provider.sales.where((s) => !s.createdAt.isBefore(r.start) && !s.createdAt.isAfter(r.end)).toList();
  }

  Future<void> _choosePeriod() async {
    final value = await showMenu<_Period>(
      context: context,
      position: const RelativeRect.fromLTRB(160, 70, 160, 0),
      items: const [
        PopupMenuItem(value: _Period.daily, child: Text('Diario')),
        PopupMenuItem(value: _Period.weekly, child: Text('Semanal')),
        PopupMenuItem(value: _Period.monthly, child: Text('Mensual')),
        PopupMenuItem(value: _Period.yearly, child: Text('Anual')),
        PopupMenuItem(value: _Period.custom, child: Text('Rango personalizado')),
      ],
    );
    if (value == null) return;
    setState(() => _period = value);
    if (value == _Period.custom) await _chooseDateRange();
  }

  Future<void> _chooseDate() async {
    if (_period == _Period.custom) { await _chooseDateRange(); return; }
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _anchor);
    if (picked != null) setState(() => _anchor = picked);
  }

  Future<void> _chooseDateRange() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDateRange: _customRange ?? DateTimeRange(start: _anchor, end: _anchor));
    if (picked != null) setState(() { _customRange = picked; _anchor = picked.start; });
  }

  String _periodName() => switch (_period) {
    _Period.daily => 'Diario',
    _Period.weekly => 'Semanal',
    _Period.monthly => 'Mensual',
    _Period.yearly => 'Anual',
    _Period.custom => 'Rango personalizado',
  };

  String _dateName() {
    if (_period == _Period.custom && _customRange != null) return '${_date(_customRange!.start)} → ${_date(_customRange!.end)}';
    if (_period == _Period.monthly) return '${_month(_anchor.month)} ${_anchor.year}';
    if (_period == _Period.yearly) return '${_anchor.year}';
    final r = _range;
    return _period == _Period.daily ? _date(_anchor) : '${_date(r.start)} → ${_date(r.end)}';
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _month(int m) => const ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'][m - 1];
  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final purchaseProvider = context.watch<PurchasesProvider>();
    final salesProvider = context.watch<SalesProvider>();
    final purchases = _purchases(purchaseProvider);
    final sales = _sales(salesProvider);
    final purchaseTotal = purchases.fold(0.0, (sum, p) => sum + p.total);
    final salesTotal = sales.fold(0.0, (sum, s) => sum + s.total);
    final grossProfit = sales.fold(0.0, (sum, s) => sum + s.items.fold(0.0, (inner, i) => inner + ((i.unitPrice - i.cost) * i.quantity) - i.discount));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          child: Column(children: [
            _filters(),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _SummaryCard('Compras', _money(purchaseTotal), Icons.shopping_bag_outlined, AppColors.dangerRed)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard('Ventas', _money(salesTotal), Icons.point_of_sale_outlined, AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard('Ganancia bruta', _money(grossProfit), Icons.trending_up_outlined, AppColors.successGreen)),
            ]),
            const SizedBox(height: 12),
            Expanded(child: Row(children: [
              Expanded(flex: 3, child: _history(purchases)),
              const SizedBox(width: 12),
              Expanded(flex: 1, child: _summary(purchases, sales, grossProfit)),
            ])),
          ]),
        ),
        Positioned(right: 20, bottom: 20, child: FloatingActionButton(shape: const CircleBorder(), backgroundColor: AppColors.primary, tooltip: 'Nueva compra', onPressed: () => showDialog<void>(context: context, builder: (_) => const AlertDialog(title: Text('Nueva compra'), content: Text('Aquí conectaremos el formulario de ingreso cuando definamos el segundo boceto.'), actions: [])), child: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white))),
      ]),
    );
  }

  Widget _filters() => Row(children: [
    Expanded(child: TextField(controller: _searchController, onChanged: (v) => setState(() => _query = v), decoration: InputDecoration(hintText: 'Buscar proveedor o factura...', prefixIcon: const Icon(Icons.search, size: 19), filled: true, fillColor: AppColors.cardBackground, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border))))),
    const SizedBox(width: 10),
    _FilterButton(_periodName(), Icons.calendar_view_month_outlined, _choosePeriod),
    const SizedBox(width: 8),
    _FilterButton(_dateName(), Icons.event_outlined, _chooseDate),
  ]);

  Widget _history(List<PurchaseRecord> purchases) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.textSecondary), const SizedBox(width: 7), const Text('Historial de compras', style: AppTextStyles.sectionTitle), const Spacer(), Text('${purchases.length}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted))]),
    const SizedBox(height: 10),
    Expanded(child: purchases.isEmpty ? const _EmptyState() : ListView.separated(padding: const EdgeInsets.only(bottom: 70), itemCount: purchases.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) => _PurchaseCard(purchases[i]))),
  ]));

  Widget _summary(List<PurchaseRecord> purchases, List<SaleRecord> sales, double profit) {
    final items = purchases.fold(0, (sum, p) => sum + p.itemCount);
    final suppliers = purchases.map((p) => p.distributorName.toLowerCase()).toSet().length;
    return _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Resumen del período', style: AppTextStyles.sectionTitle), const SizedBox(height: 12),
      _Metric('Compras', _money(purchases.fold(0.0, (s, p) => s + p.total))),
      _Metric('Ventas', _money(sales.fold(0.0, (s, v) => s + v.total))),
      _Metric('Ganancia bruta', _money(profit), AppColors.successGreen),
      const Divider(height: 22, color: AppColors.border),
      _Metric('Cantidad de compras', '${purchases.length}'),
      _Metric('Productos comprados', '$items'),
      _Metric('Proveedores', '$suppliers'),
      const Spacer(), Text('${_date(_range.start)} → ${_date(_range.end)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
    ]));
  }
}

class _FilterButton extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onPressed;
  const _FilterButton(this.label, this.icon, this.onPressed);
  @override Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 17), label: Text(label, overflow: TextOverflow.ellipsis), style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary, backgroundColor: AppColors.cardBackground, side: const BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13)));
}

class _SummaryCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color accent;
  const _SummaryCard(this.label, this.value, this.icon, this.accent);
  @override Widget build(BuildContext context) => Container(height: 82, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.cardRadius), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))]), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: accent.withAlpha(18), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: accent, size: 21)), const SizedBox(width: 11), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))]))]));
}

class _PurchaseCard extends StatelessWidget {
  final PurchaseRecord purchase; const _PurchaseCard(this.purchase);
  @override Widget build(BuildContext context) => Material(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(11), child: InkWell(onTap: () => showDialog<void>(context: context, builder: (_) => _PurchaseDetail(purchase)), borderRadius: BorderRadius.circular(11), child: Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withAlpha(16), shape: BoxShape.circle), child: const Icon(Icons.storefront_outlined, color: AppColors.primary, size: 20)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(purchase.distributorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(purchase.invoiceNumber.isEmpty ? 'Sin número de factura' : 'Factura ${purchase.invoiceNumber}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)), const SizedBox(height: 2), Text('Llegada: ${_date(purchase.arrivalAt)}', style: const TextStyle(fontSize: 9, color: AppColors.textMuted))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('\$${purchase.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(purchase.paymentMethod, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)), const SizedBox(height: 2), Text('${purchase.itemCount} productos', style: const TextStyle(fontSize: 9, color: AppColors.textMuted))]), const SizedBox(width: 4), const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted)]))));
  static String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _PurchaseDetail extends StatelessWidget {
  final PurchaseRecord purchase; const _PurchaseDetail(this.purchase);
  @override Widget build(BuildContext context) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700), child: Column(children: [Padding(padding: const EdgeInsets.fromLTRB(20, 16, 12, 12), child: Row(children: [const Icon(Icons.receipt_long_outlined, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Detalle de compra', style: AppTextStyles.sectionTitle), Text(purchase.distributorName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))])), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))])), const Divider(height: 1), Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: _Info('Factura', purchase.invoiceNumber.isEmpty ? '—' : purchase.invoiceNumber)), Expanded(child: _Info('Fecha de llegada', _date(purchase.arrivalAt))), Expanded(child: _Info('Forma de pago', purchase.paymentMethod))])), const Divider(height: 1), Expanded(child: ListView.separated(padding: const EdgeInsets.all(16), itemCount: purchase.items.length, separatorBuilder: (_, __) => const SizedBox(height: 7), itemBuilder: (_, i) => _PurchaseItem(purchase.items[i]))), Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Spacer(), const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(width: 28), Text('\$${purchase.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary))]))]));
  static String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Info extends StatelessWidget { final String label, value; const _Info(this.label, this.value); @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]); }

class _PurchaseItem extends StatelessWidget {
  final PurchaseItemRecord item; const _PurchaseItem(this.item);
  @override Widget build(BuildContext context) { final bytes = _image(item.imageData); return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 48, height: 48, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: bytes == null ? const Icon(Icons.image_outlined, color: AppColors.textMuted) : Image.memory(bytes, fit: BoxFit.cover)), const SizedBox(width: 10), SizedBox(width: 45, child: Text('${item.quantity}x', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), Text(item.unit, style: const TextStyle(fontSize: 9, color: AppColors.textMuted))])), Text('\$${item.unitCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)), const SizedBox(width: 18), Text('\$${item.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))])); }
  static Uint8List? _image(String value) { if (value.trim().isEmpty) return null; try { return base64Decode(value.contains(',') ? value.split(',').last : value); } catch (_) { return null; } }
}

class _Metric extends StatelessWidget { final String label, value; final Color? color; const _Metric(this.label, this.value, [this.color]); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))), Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color ?? AppColors.textPrimary))])); }
class _Panel extends StatelessWidget { final Widget child; const _Panel({required this.child}); @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.cardRadius), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))]), padding: const EdgeInsets.all(14), child: child); }
class _EmptyState extends StatelessWidget { const _EmptyState(); @override Widget build(BuildContext context) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shopping_bag_outlined, size: 30, color: AppColors.textMuted), SizedBox(height: 10), Text('No hay compras registradas en este período.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.textMuted))])); }
