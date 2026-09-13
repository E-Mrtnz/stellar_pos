import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/purchases_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/presentation/purchases/purchase_creation_dialog.dart';
import 'package:stellar_pos/presentation/widgets/history_table_panel.dart';
import 'package:stellar_pos/presentation/widgets/period_summary_panel.dart';
import 'package:stellar_pos/presentation/widgets/product_search_bar.dart';

class PurchasesLayout extends StatefulWidget {
  const PurchasesLayout({super.key});
  @override
  State<PurchasesLayout> createState() => _PurchasesLayoutState();
}

enum _PurchasePeriod { daily, weekly, monthly, yearly, custom }

class _PurchasesLayoutState extends State<PurchasesLayout> {
  final _searchController = TextEditingController();
  _PurchasePeriod _period = _PurchasePeriod.monthly;
  DateTime _anchorDate = DateTime.now();
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});
  String _money(double value) => '\$${value.toStringAsFixed(2)}';
  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  DateTimeRange _range() {
    final day = DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);
    switch (_period) {
      case _PurchasePeriod.daily:
        return DateTimeRange(start: day, end: day.add(const Duration(days: 1)));
      case _PurchasePeriod.weekly:
        final start = day.subtract(Duration(days: day.weekday - 1));
        return DateTimeRange(start: start, end: start.add(const Duration(days: 7)));
      case _PurchasePeriod.monthly:
        return DateTimeRange(start: DateTime(day.year, day.month), end: DateTime(day.year, day.month + 1));
      case _PurchasePeriod.yearly:
        return DateTimeRange(start: DateTime(day.year), end: DateTime(day.year + 1));
      case _PurchasePeriod.custom:
        final start = _customStart ?? day;
        final end = _customEnd ?? start;
        return DateTimeRange(start: DateTime(start.year, start.month, start.day), end: DateTime(end.year, end.month, end.day).add(const Duration(days: 1)));
    }
  }

  String _periodLabel() {
    switch (_period) {
      case _PurchasePeriod.daily: return 'Diario';
      case _PurchasePeriod.weekly: return 'Semanal';
      case _PurchasePeriod.monthly: return 'Mensual';
      case _PurchasePeriod.yearly: return 'Anual';
      case _PurchasePeriod.custom: return 'Rango personalizado';
    }
  }

  List<PurchaseRecord> _filter(List<PurchaseRecord> all) {
    final range = _range();
    final query = _searchController.text.trim().toLowerCase();
    return all.where((purchase) {
      if (purchase.arrivalAt.isBefore(range.start) || !purchase.arrivalAt.isBefore(range.end)) return false;
      if (query.isEmpty) return true;
      return purchase.distributorName.toLowerCase().contains(query) || purchase.invoiceNumber.toLowerCase().contains(query);
    }).toList()..sort((a, b) => b.arrivalAt.compareTo(a.arrivalAt));
  }

  List<SaleRecord> _sales(SalesProvider provider) {
    final range = _range();
    return provider.sales.where((sale) => !sale.createdAt.isBefore(range.start) && sale.createdAt.isBefore(range.end)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final purchasesProvider = context.watch<PurchasesProvider>();
    final salesProvider = context.watch<SalesProvider>();
    final purchases = _filter(purchasesProvider.purchases);
    final sales = _sales(salesProvider);
    final purchaseTotal = purchases.fold(0.0, (sum, purchase) => sum + purchase.total);
    final salesTotal = sales.fold(0.0, (sum, sale) => sum + sale.total);
    final profit = sales.fold(0.0, (sum, sale) => sum + sale.items.fold(0.0, (inner, item) => inner + ((item.unitPrice - item.cost) * item.quantity) - item.discount));
    final itemCount = purchases.fold(0, (sum, purchase) => sum + purchase.itemCount);
    final bonusCount = purchases.fold(0, (sum, purchase) => sum + purchase.items.fold(0, (inner, item) => inner + item.bonusQuantity));
    final supplierCount = purchases.map((p) => p.distributorName.toLowerCase()).toSet().length;
    final range = _range();

    final metrics = <PeriodSummaryMetric>[
      PeriodSummaryMetric('Compras', _money(purchaseTotal)),
      PeriodSummaryMetric('Ventas', _money(salesTotal)),
      PeriodSummaryMetric('Ganancia bruta', _money(profit), valueColor: AppColors.successGreen),
      PeriodSummaryMetric('Compras registradas', '${purchases.length}'),
      PeriodSummaryMetric('Unidades recibidas', '$itemCount'),
      PeriodSummaryMetric('Bonificaciones', '$bonusCount'),
      PeriodSummaryMetric('Distribuidoras', '$supplierCount'),
    ];

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Compras', style: AppTextStyles.brandTitle), SizedBox(height: 3), Text('Historial y registro de las compras realizadas.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))])),
                OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today_outlined, size: 16), label: Text(_period == _PurchasePeriod.custom ? 'Elegir rango' : _periodLabel())),
                const SizedBox(width: 8),
                PopupMenuButton<_PurchasePeriod>(onSelected: (value) => value == _PurchasePeriod.custom ? _pickRange() : setState(() => _period = value), itemBuilder: (_) => const [PopupMenuItem(value: _PurchasePeriod.daily, child: Text('Diario')), PopupMenuItem(value: _PurchasePeriod.weekly, child: Text('Semanal')), PopupMenuItem(value: _PurchasePeriod.monthly, child: Text('Mensual')), PopupMenuItem(value: _PurchasePeriod.yearly, child: Text('Anual')), PopupMenuItem(value: _PurchasePeriod.custom, child: Text('Rango personalizado'))], child: _menuSurface(Icons.tune_outlined, _periodLabel())),
              ]),
              const SizedBox(height: 10),
              Row(children: [_metric('Compras', purchaseTotal, Icons.shopping_bag_outlined, AppColors.dangerRed), const SizedBox(width: 8), _metric('Ventas', salesTotal, Icons.point_of_sale_outlined, AppColors.primary), const SizedBox(width: 8), _metric('Ganancia bruta', profit, Icons.trending_up_outlined, AppColors.successGreen)]),
              const SizedBox(height: 12),
              ProductSearchBar(controller: _searchController, hintText: 'Buscar proveedor o factura...', onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
              Expanded(child: Row(children: [Expanded(flex: 3, child: _list(purchases)), const SizedBox(width: 12), Expanded(child: PeriodSummaryPanel(metrics: metrics, rangeLabel: '${_date(range.start)} → ${_date(range.end.subtract(const Duration(days: 1)))}'))])),
            ],
          ),
          Positioned(right: 0, bottom: 0, child: FloatingActionButton.extended(onPressed: _newPurchase, backgroundColor: AppColors.primary, icon: const Icon(Icons.add_shopping_cart_outlined, color: Colors.white), label: const Text('Nueva compra', style: TextStyle(color: Colors.white)))),
        ],
      ),
    );
  }

  Widget _metric(String label, double amount, IconData icon, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(_money(amount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _menuSurface(IconData icon, String label) => Container(constraints: const BoxConstraints(minHeight: 42), padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: AppColors.textSecondary), const SizedBox(width: 7), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))]));

  Widget _list(List<PurchaseRecord> purchases) => HistoryTablePanel(title: 'Historial de compras', icon: Icons.receipt_long_outlined, itemCount: purchases.length, header: Container(padding: const EdgeInsets.fromLTRB(14, 10, 14, 9), color: AppColors.inputBackground, child: const Row(children: [Expanded(flex: 2, child: Text('Distribuidora / factura', style: AppTextStyles.ticketLabel)), SizedBox(width: 105, child: Text('Fecha / hora', style: AppTextStyles.ticketLabel)), Expanded(child: Text('Artículos', style: AppTextStyles.ticketLabel)), SizedBox(width: 90, child: Text('Pago', style: AppTextStyles.ticketLabel)), SizedBox(width: 95, child: Text('Total', textAlign: TextAlign.right, style: AppTextStyles.ticketLabel)), SizedBox(width: 26)])), emptyState: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shopping_bag_outlined, size: 40, color: AppColors.textMuted), SizedBox(height: 10), Text('No hay compras registradas en este período.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))])), itemBuilder: (_, index) => _row(purchases[index]));

  Widget _row(PurchaseRecord purchase) {
    final time = '${purchase.arrivalAt.hour.toString().padLeft(2, '0')}:${purchase.arrivalAt.minute.toString().padLeft(2, '0')}';
    return InkWell(onTap: () => _detail(purchase), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(purchase.distributorName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(purchase.invoiceNumber.isEmpty ? 'Sin número de factura' : 'Factura ${purchase.invoiceNumber}', style: const TextStyle(fontSize: 9, color: AppColors.textMuted))])), SizedBox(width: 105, child: Text('${_date(purchase.arrivalAt)}\n$time', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))), Expanded(child: Text('${purchase.itemCount} unidades', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))), SizedBox(width: 90, child: _payment(purchase.paymentMethod)), SizedBox(width: 95, child: Text(_money(purchase.total), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))), const SizedBox(width: 8), const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted)])));
  }

  Widget _payment(String method) => Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(8)), child: Text(method.isEmpty ? 'Contado' : method, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textDarkSecondary))));

  Future<void> _newPurchase() async {
    final created = await PurchaseCreationDialog.show(context);
    if (created == true && mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    if (_period == _PurchasePeriod.custom) return _pickRange();
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _anchorDate);
    if (picked != null) setState(() => _anchorDate = picked);
  }

  Future<void> _pickRange() async {
    final start = _customStart ?? _anchorDate;
    final end = _customEnd ?? start;
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDateRange: DateTimeRange(start: start, end: end.isBefore(start) ? start : end));
    if (picked == null) return;
    setState(() { _period = _PurchasePeriod.custom; _customStart = picked.start; _customEnd = picked.end; _anchorDate = picked.start; });
  }

  void _detail(PurchaseRecord purchase) => showDialog<void>(context: context, builder: (_) => _PurchaseDetailDialog(purchase));
}

class _PurchaseDetailDialog extends StatelessWidget {
  final PurchaseRecord purchase;
  const _PurchaseDetailDialog(this.purchase);

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700), child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 16, 12, 12), child: Row(children: [const Icon(Icons.receipt_long_outlined, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Detalle de compra', style: AppTextStyles.sectionTitle), Text(purchase.distributorName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))])), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))])),
    const Divider(height: 1),
    Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: _info('Factura', purchase.invoiceNumber.isEmpty ? '—' : purchase.invoiceNumber)), Expanded(child: _info('Fecha', _date(purchase.arrivalAt))), Expanded(child: _info('Pago', 'Contado'))])),
    const Divider(height: 1),
    Expanded(child: ListView.separated(padding: const EdgeInsets.all(16), itemCount: purchase.items.length, separatorBuilder: (_, __) => const SizedBox(height: 7), itemBuilder: (_, index) => _item(purchase.items[index]))),
    Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Spacer(), const Text('Total pagado', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(width: 28), Text(_money(purchase.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary))])),
  ])));

  Widget _info(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]);

  Widget _item(PurchaseItemRecord item) {
    final image = _decode(item.imageData);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 48, height: 48, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8)), child: image == null ? const Icon(Icons.image_outlined, color: AppColors.textMuted) : Image.memory(image, fit: BoxFit.contain)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), Text('${item.quantity} compradas  •  ${item.bonusQuantity} bonificadas  •  ${item.totalQuantity} recibidas', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary))])), Text(_money(item.unitCost), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)), const SizedBox(width: 18), Text(_money(item.total), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))]));
  }

  Uint8List? _decode(String value) {
    if (value.trim().isEmpty) return null;
    try { return base64Decode(value.contains(',') ? value.split(',').last : value); } catch (_) { return null; }
  }
}
