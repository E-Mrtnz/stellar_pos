import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/debt_provider.dart';
import 'package:stellar_pos/core/providers/printer_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sale_detail_dialog.dart';
import 'package:stellar_pos/presentation/widgets/product_search_bar.dart';

class SalesLayout extends StatefulWidget {
  const SalesLayout({super.key});

  @override
  State<SalesLayout> createState() => _SalesLayoutState();
}

enum _SalesPeriod { daily, weekly, monthly, yearly, custom }
enum _SalesPaymentFilter { all, cash, card, transfer, credit }

class _SalesLayoutState extends State<SalesLayout> {
  final TextEditingController _searchController = TextEditingController();
  _SalesPeriod _period = _SalesPeriod.daily;
  _SalesPaymentFilter _paymentFilter = _SalesPaymentFilter.all;
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

  DateTimeRange _range() {
    final day = DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);
    switch (_period) {
      case _SalesPeriod.daily:
        return DateTimeRange(start: day, end: day.add(const Duration(days: 1)));
      case _SalesPeriod.weekly:
        final start = day.subtract(Duration(days: day.weekday - 1));
        return DateTimeRange(start: start, end: start.add(const Duration(days: 7)));
      case _SalesPeriod.monthly:
        return DateTimeRange(start: DateTime(day.year, day.month), end: DateTime(day.year, day.month + 1));
      case _SalesPeriod.yearly:
        return DateTimeRange(start: DateTime(day.year), end: DateTime(day.year + 1));
      case _SalesPeriod.custom:
        final start = _customStart ?? day;
        final end = _customEnd ?? start;
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(end.year, end.month, end.day).add(const Duration(days: 1)),
        );
    }
  }

  String _periodLabel() {
    switch (_period) {
      case _SalesPeriod.daily: return 'Diario';
      case _SalesPeriod.weekly: return 'Semanal';
      case _SalesPeriod.monthly: return 'Mensual';
      case _SalesPeriod.yearly: return 'Anual';
      case _SalesPeriod.custom: return 'Rango personalizado';
    }
  }

  String _dateLabel() {
    if (_period == _SalesPeriod.monthly) return '${_anchorDate.month.toString().padLeft(2, '0')}/${_anchorDate.year}';
    return '${_anchorDate.day.toString().padLeft(2, '0')}/${_anchorDate.month.toString().padLeft(2, '0')}/${_anchorDate.year}';
  }

  List<SaleRecord> _filterSales(List<SaleRecord> sales) {
    final range = _range();
    final query = _searchController.text.trim().toLowerCase();
    final result = sales.where((sale) {
      if (sale.createdAt.isBefore(range.start) || !sale.createdAt.isBefore(range.end)) return false;
      if (!_paymentMatches(sale)) return false;
      if (query.isEmpty) return true;
      return sale.ticketNumber.toLowerCase().contains(query) ||
          sale.clientName.toLowerCase().contains(query) ||
          sale.items.any((item) => item.productName.toLowerCase().contains(query) || item.barcode.toLowerCase().contains(query));
    }).toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  bool _paymentMatches(SaleRecord sale) {
    switch (_paymentFilter) {
      case _SalesPaymentFilter.all: return true;
      case _SalesPaymentFilter.cash: return sale.paymentMethod == AppStrings.cashPayment;
      case _SalesPaymentFilter.card: return sale.paymentMethod == AppStrings.cardPayment;
      case _SalesPaymentFilter.transfer: return sale.paymentMethod == AppStrings.transferPayment;
      case _SalesPaymentFilter.credit: return sale.paymentMethod == AppStrings.creditPayment;
    }
  }

  Map<String, double> _paidBySale(List<SaleRecord> allSales, List<DebtMovement> movements) {
    final credits = allSales.where((sale) => sale.paymentMethod == AppStrings.creditPayment && sale.clientId != null).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final paid = <String, double>{for (final sale in credits) sale.id: 0};
    final payments = movements.where((movement) => movement.type == DebtMovementType.payment).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final payment in payments) {
      var remaining = payment.amount;
      for (final sale in credits.where((sale) => sale.clientId == payment.clientId)) {
        final outstanding = sale.total - (paid[sale.id] ?? 0);
        if (outstanding <= 0.005) continue;
        final applied = remaining > outstanding ? outstanding : remaining;
        paid[sale.id] = (paid[sale.id] ?? 0) + applied;
        remaining -= applied;
        if (remaining <= 0.005) break;
      }
    }
    return paid;
  }

  double _collectedFromSale(SaleRecord sale) {
    if (sale.paymentMethod == AppStrings.creditPayment) return sale.received.clamp(0, sale.total).toDouble();
    return sale.total;
  }

  double _laterPayments(List<DebtMovement> movements, DateTimeRange range) {
    return movements.where((movement) =>
      movement.type == DebtMovementType.payment &&
      movement.reference == null &&
      !movement.createdAt.isBefore(range.start) &&
      movement.createdAt.isBefore(range.end),
    ).fold(0, (sum, movement) => sum + movement.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SalesProvider, DebtProvider>(
      builder: (context, salesProvider, debtProvider, _) {
        final sales = _filterSales(salesProvider.sales);
        final allSales = salesProvider.sales;
        final paidBySale = _paidBySale(allSales, debtProvider.movements);
        final range = _range();
        final totalSold = sales.fold(0.0, (sum, sale) => sum + sale.total);
        final collected = sales.fold(0.0, (sum, sale) => sum + _collectedFromSale(sale));
        final credit = sales.where((sale) => sale.paymentMethod == AppStrings.creditPayment)
            .fold(0.0, (sum, sale) => sum + sale.total - sale.received.clamp(0, sale.total));
        final laterPayments = _laterPayments(debtProvider.movements, range);
        final profit = sales.fold(0.0, (sum, sale) => sum + sale.items.fold(0.0, (line, item) => line + (item.unitPrice - item.cost) * item.quantity - item.discount));

        return Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildMetrics(totalSold, collected, credit, laterPayments),
              const SizedBox(height: 12),
              _buildFilters(),
              const SizedBox(height: 12),
              Expanded(child: _buildList(sales, paidBySale)),
              const SizedBox(height: 7),
              Row(children: [
                Text('${sales.length} venta${sales.length == 1 ? '' : 's'} en ${_periodLabel()}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const Spacer(),
                Text('Ganancia estimada: ${_money(profit)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.successGreen)),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ventas', style: AppTextStyles.brandTitle),
        SizedBox(height: 3),
        Text('Historial y registro de las ventas realizadas.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today_outlined, size: 16), label: Text(_period == _SalesPeriod.custom ? 'Elegir rango' : _dateLabel())),
      const SizedBox(width: 8),
      PopupMenuButton<_SalesPeriod>(
        onSelected: (value) {
          if (value == _SalesPeriod.custom) {
            _pickRange();
          } else {
            setState(() => _period = value);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: _SalesPeriod.daily, child: Text('Diario')),
          PopupMenuItem(value: _SalesPeriod.weekly, child: Text('Semanal')),
          PopupMenuItem(value: _SalesPeriod.monthly, child: Text('Mensual')),
          PopupMenuItem(value: _SalesPeriod.yearly, child: Text('Anual')),
          PopupMenuItem(value: _SalesPeriod.custom, child: Text('Rango personalizado')),
        ],
        child: OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.tune_outlined, size: 17), label: Text(_periodLabel())),
      ),
    ]);
  }

  Future<void> _pickDate() async {
    if (_period == _SalesPeriod.custom) return _pickRange();
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _anchorDate);
    if (picked != null) setState(() => _anchorDate = picked);
  }

  Future<void> _pickRange() async {
    final start = _customStart ?? _anchorDate;
    final end = _customEnd ?? start;
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDateRange: DateTimeRange(start: start, end: end.isBefore(start) ? start : end));
    if (picked == null) return;
    setState(() {
      _period = _SalesPeriod.custom;
      _customStart = picked.start;
      _customEnd = picked.end;
      _anchorDate = picked.start;
    });
  }

  Widget _buildMetrics(double sold, double collected, double credit, double laterPayments) {
    return Row(children: [
      Expanded(child: _metric('Total vendido', sold, Icons.receipt_long_outlined, AppColors.primary)),
      const SizedBox(width: 8),
      Expanded(child: _metric('Cobrado por ventas', collected, Icons.payments_outlined, AppColors.successGreen)),
      const SizedBox(width: 8),
      Expanded(child: _metric('Fiado generado', credit, Icons.account_balance_wallet_outlined, AppColors.dangerRed)),
      const SizedBox(width: 8),
      Expanded(child: _metric('Abonos cobrados', laterPayments, Icons.savings_outlined, AppColors.warningOrange)),
    ]);
  }

  Widget _metric(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.cardRadius), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 8, offset: Offset(0, 3))]),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(_money(amount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ])),
      ]),
    );
  }

  Widget _buildFilters() {
    return Row(children: [
      Expanded(child: ProductSearchBar(controller: _searchController, hintText: 'Buscar venta, cliente, producto o código...', onChanged: (_) {})),
      const SizedBox(width: 8),
      PopupMenuButton<_SalesPaymentFilter>(
        onSelected: (value) => setState(() => _paymentFilter = value),
        itemBuilder: (_) => const [
          PopupMenuItem(value: _SalesPaymentFilter.all, child: Text('Todos')),
          PopupMenuItem(value: _SalesPaymentFilter.cash, child: Text('Efectivo')),
          PopupMenuItem(value: _SalesPaymentFilter.card, child: Text('Tarjeta')),
          PopupMenuItem(value: _SalesPaymentFilter.transfer, child: Text('Transferencia')),
          PopupMenuItem(value: _SalesPaymentFilter.credit, child: Text('Fiado')),
        ],
        child: OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.filter_alt_outlined, size: 17), label: Text(_paymentLabel())),
      ),
    ]);
  }

  String _paymentLabel() {
    switch (_paymentFilter) {
      case _SalesPaymentFilter.all: return 'Todos';
      case _SalesPaymentFilter.cash: return 'Efectivo';
      case _SalesPaymentFilter.card: return 'Tarjeta';
      case _SalesPaymentFilter.transfer: return 'Transferencia';
      case _SalesPaymentFilter.credit: return 'Fiado';
    }
  }

  Widget _buildList(List<SaleRecord> sales, Map<String, double> paidBySale) {
    if (sales.isEmpty) {
      return Container(decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.cardRadius), border: Border.all(color: AppColors.border)), child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted), SizedBox(height: 10), Text('No hay ventas en este período.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))])));
    }
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.cardRadius), border: Border.all(color: AppColors.border)),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 3),
        itemCount: sales.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, index) => _saleRow(sales[index], paidBySale[sales[index].id] ?? 0),
      ),
    );
  }

  Widget _saleRow(SaleRecord sale, double paid) {
    final credit = sale.paymentMethod == AppStrings.creditPayment;
    final pending = credit ? (sale.total - paid).clamp(0, double.infinity).toDouble() : 0.0;
    final items = sale.items.fold<int>(0, (sum, item) => sum + item.quantity);
    final date = '${sale.createdAt.day.toString().padLeft(2, '0')}/${sale.createdAt.month.toString().padLeft(2, '0')}/${sale.createdAt.year}';
    final time = '${sale.createdAt.hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: () => _showDetails(sale, paid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          SizedBox(width: 78, child: Text('#${sale.ticketNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
          SizedBox(width: 105, child: Text('$date\n$time', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
          Expanded(flex: 2, child: Text(sale.clientName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(child: Text('$items artículo${items == 1 ? '' : 's'}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
          SizedBox(width: 100, child: _paymentBadge(sale.paymentMethod)),
          SizedBox(width: 100, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(_money(sale.total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), if (credit) Text(pending <= .005 ? 'Pagada' : 'Pendiente ${_money(pending)}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: pending <= .005 ? AppColors.successGreen : AppColors.dangerRed))])),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  Widget _paymentBadge(String method) => Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(8)), child: Text(method, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textDarkSecondary))));

  Future<void> _showDetails(SaleRecord sale, double paid) async {
    await SaleDetailDialog.show(context, sale: sale, paidAmount: paid, onPrint: () => _printSale(sale));
  }

  Future<void> _printSale(SaleRecord sale) async {
    final printer = context.read<PrinterProvider>();
    final printed = await printer.printSaleTicket(sale);
    if (!mounted) return;
    AppAlert.show(context, printed ? 'El ticket fue enviado a la impresora.' : (printer.errorMessage ?? 'No se pudo imprimir el ticket.'), title: printed ? 'Impresión completada' : 'No se pudo imprimir', type: printed ? AppAlertType.success : AppAlertType.warning);
  }
}
