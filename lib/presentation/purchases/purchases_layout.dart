import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/providers/purchases_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';

class PurchasesLayout extends StatefulWidget {
  const PurchasesLayout({super.key});

  @override
  State<PurchasesLayout> createState() => _PurchasesLayoutState();
}

enum _PurchasePeriod { daily, weekly, monthly, yearly, custom }

class _PurchasesLayoutState extends State<PurchasesLayout> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  _PurchasePeriod _period = _PurchasePeriod.monthly;
  DateTime _anchorDate = DateTime.now();
  DateTimeRange? _customRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTimeRange get _range {
    if (_period == _PurchasePeriod.custom && _customRange != null) {
      return DateTimeRange(
        start: DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day),
        end: DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59, 999),
      );
    }

    final d = _anchorDate;
    switch (_period) {
      case _PurchasePeriod.daily:
        return DateTimeRange(start: DateTime(d.year, d.month, d.day), end: DateTime(d.year, d.month, d.day, 23, 59, 59, 999));
      case _PurchasePeriod.weekly:
        final start = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - DateTime.monday));
        return DateTimeRange(start: start, end: start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999)));
      case _PurchasePeriod.monthly:
        return DateTimeRange(start: DateTime(d.year, d.month), end: DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999));
      case _PurchasePeriod.yearly:
        return DateTimeRange(start: DateTime(d.year), end: DateTime(d.year + 1, 0, 0, 23, 59, 59, 999));
      case _PurchasePeriod.custom:
        return DateTimeRange(start: DateTime(d.year, d.month), end: DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999));
    }
  }

  List<PurchaseRecord> _filteredPurchases(List<PurchaseRecord> source) {
    final r = _range;
    final query = _search.trim().toLowerCase();
    final result = source.where((purchase) {
      if (purchase.purchasedAt.isBefore(r.start) || purchase.purchasedAt.isAfter(r.end)) return false;
      if (query.isEmpty) return true;
      return purchase.distributorName.toLowerCase().contains(query) ||
          purchase.invoiceNumber.toLowerCase().contains(query);
    }).toList();
    result.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    return result;
  }

  List<SaleRecordLike> _salesForRange(SalesProvider provider) {
    final r = _range;
    return provider.sales
        .where((sale) => !sale.createdAt.isBefore(r.start) && !sale.createdAt.isAfter(r.end))
        .map((sale) => SaleRecordLike(sale))
        .toList();
  }

  Future<void> _pickDate() async {
    if (_period == _PurchasePeriod.custom) {
      final initial = _customRange ?? DateTimeRange(start: _anchorDate, end: _anchorDate);
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: initial,
      );
      if (picked == null) return;
      setState(() {
        _customRange = picked;
        _anchorDate = picked.start;
      });
      return;
    }

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _anchorDate,
    );
    if (picked != null) setState(() => _anchorDate = picked);
  }

  String _periodLabel() {
    switch (_period) {
      case _PurchasePeriod.daily:
        return 'Diario';
      case _PurchasePeriod.weekly:
        return 'Semanal';
      case _PurchasePeriod.monthly:
        return 'Mensual';
      case _PurchasePeriod.yearly:
        return 'Anual';
      case _PurchasePeriod.custom:
        return 'Rango personalizado';
    }
  }

  String _dateLabel() {
    if (_period == _PurchasePeriod.custom && _customRange != null) {
      return '${_shortDate(_customRange!.start)} → ${_shortDate(_customRange!.end)}';
    }
    switch (_period) {
      case _PurchasePeriod.daily:
        return _shortDate(_anchorDate);
      case _PurchasePeriod.weekly:
        final r = _range;
        return '${_shortDate(r.start)} → ${_shortDate(r.end)}';
      case _PurchasePeriod.monthly:
        return '${_monthName(_anchorDate.month)} ${_anchorDate.year}';
      case _PurchasePeriod.yearly:
        return '${_anchorDate.year}';
      case _PurchasePeriod.custom:
        return 'Seleccionar fechas';
    }
  }

  String _shortDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _monthName(int month) {
    const names = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return names[month - 1];
  }

  Future<void> _showNewPurchaseMessage() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva compra'),
        content: const Text('La pantalla para ingresar una compra se conectará aquí cuando definamos el segundo boceto.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final purchasesProvider = context.watch<PurchasesProvider>();
    final salesProvider = context.watch<SalesProvider>();
    final purchases = _filteredPurchases(purchasesProvider.purchases);
    final sales = _salesForRange(salesProvider);
    final purchaseTotal = purchasesProvider.totalFor(purchases);
    final salesTotal = sales.fold(0.0, (sum, sale) => sum + sale.total);
    final grossProfit = sales.fold(0.0, (sum, sale) => sum + sale.grossProfit);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilters(),
                const SizedBox(height: 12),
                _buildSummary(purchaseTotal, salesTotal, grossProfit),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _buildPurchaseHistory(purchases)),
                      const SizedBox(width: 12),
                      Expanded(flex: 1, child: _buildPeriodSummary(purchases, sales, grossProfit)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              heroTag: 'fab_new_purchase',
              tooltip: 'Nueva compra',
              onPressed: _showNewPurchaseMessage,
              shape: const CircleBorder(),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'Buscar proveedor o factura...',
              prefixIcon: const Icon(Icons.search, size: 19),
              suffixIcon: _search.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() => _search = ''); }, icon: const Icon(Icons.close, size: 17)),
              filled: true,
              fillColor: AppColors.cardBackground,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _FilterButton(label: _periodLabel(), icon: Icons.calendar_view_month_outlined, onPressed: () async {
          final selected = await showMenu<_PurchasePeriod>(
            context: context,
            position: RelativeRect.fromLTRB(0, 70, 0, 0),
            items: const [
              PopupMenuItem(value: _PurchasePeriod.daily, child: Text('Diario')),
              PopupMenuItem(value: _PurchasePeriod.weekly, child: Text('Semanal')),
              PopupMenuItem(value: _PurchasePeriod.monthly, child: Text('Mensual')),
              PopupMenuItem(value: _PurchasePeriod.yearly, child: Text('Anual')),
              PopupMenuItem(value: _PurchasePeriod.custom, child: Text('Rango personalizado')),
            ],
          );
          if (selected == null) return;
          setState(() => _period = selected);
          if (selected == _PurchasePeriod.custom) await _pickDate();
        }),
        const SizedBox(width: 8),
        _FilterButton(label: _dateLabel(), icon: Icons.event_outlined, onPressed: _pickDate),
      ],
    );
  }

  Widget _buildSummary(double purchases, double sales, double profit) {
    return Row(
      children: [
        Expanded(child: _SummaryCard(label: 'Compras', value: _money(purchases), icon: Icons.shopping_bag_outlined, accent: AppColors.dangerRed)),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(label: 'Ventas', value: _money(sales), icon: Icons.point_of_sale_outlined, accent: AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(child: _SummaryCard(label: 'Ganancia bruta', value: _money(profit), icon: Icons.trending_up_outlined, accent: AppColors.successGreen)),
      ],
    );
  }

  Widget _buildPurchaseHistory(List<PurchaseRecord> purchases) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.textSecondary), const SizedBox(width: 7), const Text('Historial de compras', style: AppTextStyles.sectionTitle), const Spacer(), Text('${purchases.length}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted))]),
          const SizedBox(height: 10),
          Expanded(
            child: purchases.isEmpty
                ? const _EmptyState(icon: Icons.shopping_bag_outlined, message: 'No hay compras registradas en este período.')
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 70),
                    itemCount: purchases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _PurchaseCard(purchase: purchases[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSummary(List<PurchaseRecord> purchases, List<SaleRecordLike> sales, double profit) {
    final providerCount = purchases.map((p) => p.distributorName.toLowerCase()).toSet().length;
    final itemCount = purchases.fold<int>(0, (sum, p) => sum + p.itemCount);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Resumen del período', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 12),
          _MetricRow(label: 'Compras', value: _money(purchases.fold(0.0, (sum, p) => sum + p.total))),
          _MetricRow(label: 'Ventas', value: _money(sales.fold(0.0, (sum, s) => sum + s.total))),
          _MetricRow(label: 'Ganancia bruta', value: _money(profit), valueColor: AppColors.successGreen),
          const Divider(height: 22, color: AppColors.border),
          _MetricRow(label: 'Cantidad de compras', value: '${purchases.length}'),
          _MetricRow(label: 'Productos comprados', value: '$itemCount'),
          _MetricRow(label: 'Proveedores', value: '$providerCount'),
          const Spacer(),
          Text(_rangeDescription(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  String _rangeDescription() {
    final r = _range;
    return '${_shortDate(r.start)} → ${_shortDate(r.end)}';
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
}

class SaleRecordLike {
  final dynamic sale;
  SaleRecordLike(this.sale);
  double get total => sale.total as double;
  double get grossProfit => (sale.items as List).fold<double>(0.0, (sum, item) => sum + ((item.unitPrice as double) - (item.cost as double)) * (item.quantity as int) - (item.discount as double));
}

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _FilterButton({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.cardBackground,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.cardRadius), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))]),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: accent.withAlpha(18), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: accent, size: 21)),
        const SizedBox(width: 11),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))])),
      ]),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final PurchaseRecord purchase;
  const _PurchaseCard({required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withAlpha(16), shape: BoxShape.circle), child: const Icon(Icons.storefront_outlined, color: AppColors.primary, size: 20)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(purchase.distributorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(purchase.invoiceNumber.isEmpty ? 'Sin número de factura' : 'Factura ${purchase.invoiceNumber}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text('Compra ${_date(purchase.purchasedAt)} · Llegada ${purchase.arrivalAt == null ? '—' : _date(purchase.arrivalAt!)}', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
              ])),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('\$${purchase.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(purchase.paymentMethod, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)), const SizedBox(height: 2), Text('${purchase.itemCount} productos', style: const TextStyle(fontSize: 9, color: AppColors.textMuted))]),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetail(BuildContext context) async {
    await showDialog<void>(context: context, builder: (_) => _PurchaseDetailDialog(purchase: purchase));
  }

  static String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _PurchaseDetailDialog extends StatelessWidget {
  final PurchaseRecord purchase;
  const _PurchaseDetailDialog({required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Material(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 18, 16, 14), child: Row(children: [const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Detalle de compra', style: AppTextStyles.sectionTitle), const SizedBox(height: 2), Text(purchase.distributorName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))])), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 19))])),
            const Divider(height: 1, color: AppColors.border),
            Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 8), child: Row(children: [Expanded(child: _Info(label: 'Factura', value: purchase.invoiceNumber.isEmpty ? '—' : purchase.invoiceNumber)), Expanded(child: _Info(label: 'Fecha de llegada', value: _date(purchase.arrivalAt))), Expanded(child: _Info(label: 'Forma de pago', value: purchase.paymentMethod))])),
            const Divider(height: 1, color: AppColors.border),
            Expanded(child: ListView.separated(padding: const EdgeInsets.all(16), itemCount: purchase.items.length, separatorBuilder: (_, __) => const SizedBox(height: 7), itemBuilder: (_, index) => _PurchaseItemRow(item: purchase.items[index]))),
            Container(padding: const EdgeInsets.fromLTRB(20, 12, 20, 16), decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))), child: Row(children: [const Spacer(), const Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const SizedBox(width: 30), Text('\$${purchase.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary))])),
          ]),
        ),
      ),
    );
  }

  static String _date(DateTime? d) => d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)), const SizedBox(height: 3), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]);
}

class _PurchaseItemRow extends StatelessWidget {
  final PurchaseItemRecord item;
  const _PurchaseItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(item.imageData);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 48, height: 48, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: bytes == null ? const Icon(Icons.image_outlined, color: AppColors.textMuted, size: 20) : Image.memory(bytes, fit: BoxFit.cover)),
        const SizedBox(width: 10),
        SizedBox(width: 48, child: Text('${item.quantity}x', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(item.unit, style: const TextStyle(fontSize: 9, color: AppColors.textMuted))])),
        Text('\$${item.unitCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(width: 18),
        Text('\$${item.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Uint8List? _decode(String value) {
    if (value.trim().isEmpty) return null;
    try { return base64Decode(value.contains(',') ? value.split(',').last : value); } catch (_) { return null; }
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _MetricRow({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))), Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary))]));
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.cardRadius), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))]), padding: const EdgeInsets.all(14), child: child);
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 30, color: AppColors.textMuted), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))]));
}
