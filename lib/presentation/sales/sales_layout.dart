import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/debt_provider.dart';
import 'package:stellar_pos/core/providers/printer_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sale_detail_dialog.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';
import 'package:stellar_pos/presentation/widgets/history_table_panel.dart';
import 'package:stellar_pos/presentation/widgets/period_summary_panel.dart';
import 'package:stellar_pos/presentation/widgets/product_search_bar.dart';

class SalesLayout extends StatefulWidget {
  const SalesLayout({super.key});
  @override
  State<SalesLayout> createState() => _SalesLayoutState();
}

enum _SalesPeriod { daily, weekly, monthly, yearly, custom }

enum _SalesPaymentFilter { all, cash, card, transfer, credit }

enum _SalesTypeFilter { all, products, electronic }

class _SalesLayoutState extends State<SalesLayout> {
  final TextEditingController _searchController = TextEditingController();
  _SalesPeriod _period = _SalesPeriod.daily;
  _SalesPaymentFilter _paymentFilter = _SalesPaymentFilter.all;
  _SalesTypeFilter _typeFilter = _SalesTypeFilter.all;
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
  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  DateTimeRange _range() {
    final day = DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);
    switch (_period) {
      case _SalesPeriod.daily:
        return DateTimeRange(start: day, end: day.add(const Duration(days: 1)));
      case _SalesPeriod.weekly:
        final start = day.subtract(Duration(days: day.weekday - 1));
        return DateTimeRange(
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case _SalesPeriod.monthly:
        return DateTimeRange(
          start: DateTime(day.year, day.month),
          end: DateTime(day.year, day.month + 1),
        );
      case _SalesPeriod.yearly:
        return DateTimeRange(
          start: DateTime(day.year),
          end: DateTime(day.year + 1),
        );
      case _SalesPeriod.custom:
        final start = _customStart ?? day;
        final end = _customEnd ?? start;
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(
            end.year,
            end.month,
            end.day,
          ).add(const Duration(days: 1)),
        );
    }
  }

  String _periodLabel() {
    switch (_period) {
      case _SalesPeriod.daily:
        return 'Diario';
      case _SalesPeriod.weekly:
        return 'Semanal';
      case _SalesPeriod.monthly:
        return 'Mensual';
      case _SalesPeriod.yearly:
        return 'Anual';
      case _SalesPeriod.custom:
        return 'Rango personalizado';
    }
  }

  String _dateLabel() => _period == _SalesPeriod.monthly
      ? '${_anchorDate.month.toString().padLeft(2, '0')}/${_anchorDate.year}'
      : _date(_anchorDate);
  List<SaleRecord> _filterSales(List<SaleRecord> sales) {
    final range = _range();
    final query = _searchController.text.trim().toLowerCase();
    return sales.where((sale) {
      if (sale.createdAt.isBefore(range.start) ||
          !sale.createdAt.isBefore(range.end))
        return false;
      if (!_paymentMatches(sale) || !_typeMatches(sale)) return false;
      if (query.isEmpty) return true;
      return sale.ticketNumber.toLowerCase().contains(query) ||
          sale.clientName.toLowerCase().contains(query) ||
          sale.items.any(
            (item) =>
                item.productName.toLowerCase().contains(query) ||
                item.barcode.toLowerCase().contains(query),
          );
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  bool _paymentMatches(SaleRecord sale) {
    switch (_paymentFilter) {
      case _SalesPaymentFilter.all:
        return true;
      case _SalesPaymentFilter.cash:
        return sale.paymentMethod == AppStrings.cashPayment;
      case _SalesPaymentFilter.card:
        return sale.paymentMethod == AppStrings.cardPayment;
      case _SalesPaymentFilter.transfer:
        return sale.paymentMethod == AppStrings.transferPayment;
      case _SalesPaymentFilter.credit:
        return sale.paymentMethod == AppStrings.creditPayment;
    }
  }

  bool _typeMatches(SaleRecord sale) {
    final hasElectronic = sale.items.any((item) => item.isElectronicBalance);
    final hasProducts = sale.items.any((item) => !item.isElectronicBalance);
    switch (_typeFilter) {
      case _SalesTypeFilter.all:
        return true;
      case _SalesTypeFilter.products:
        return hasProducts;
      case _SalesTypeFilter.electronic:
        return hasElectronic;
    }
  }

  Map<String, double> _paidBySale(
    List<SaleRecord> allSales,
    List<DebtMovement> movements,
  ) {
    final credits =
        allSales
            .where(
              (sale) =>
                  sale.paymentMethod == AppStrings.creditPayment &&
                  sale.clientId != null,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final paid = <String, double>{for (final sale in credits) sale.id: 0};
    final payments =
        movements
            .where((movement) => movement.type == DebtMovementType.payment)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final payment in payments) {
      var remaining = payment.amount;
      for (final sale in credits.where(
        (sale) => sale.clientId == payment.clientId,
      )) {
        final outstanding = sale.effectiveTotal - (paid[sale.id] ?? 0);
        if (outstanding <= 0.005) continue;
        final applied = remaining > outstanding ? outstanding : remaining;
        paid[sale.id] = (paid[sale.id] ?? 0) + applied;
        remaining -= applied;
        if (remaining <= 0.005) break;
      }
    }
    return paid;
  }

  double _collectedFromSale(SaleRecord sale) => sale.effectiveCollected;
  double _laterPayments(List<DebtMovement> movements, DateTimeRange range) =>
      movements
          .where(
            (movement) =>
                movement.type == DebtMovementType.payment &&
                movement.reference == null &&
                !movement.createdAt.isBefore(range.start) &&
                movement.createdAt.isBefore(range.end),
          )
          .fold(0, (sum, movement) => sum + movement.amount);
  int _effectiveItemCount(SaleRecord sale) {
    if (sale.isAnnulled) return 0;
    var count = sale.items.fold<int>(0, (sum, item) => sum + item.quantity);
    for (final operation in sale.operations) {
      count -= operation.itemsOut.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );
      count += operation.itemsIn.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );
    }
    return count.clamp(0, 1 << 30);
  }

  @override
  Widget build(BuildContext context) => Consumer2<SalesProvider, DebtProvider>(
    builder: (context, salesProvider, debtProvider, _) {
      final sales = _filterSales(salesProvider.sales);
      final paidBySale = _paidBySale(
        salesProvider.sales,
        debtProvider.movements,
      );
      final range = _range();
      final totalSold = sales.fold(
        0.0,
        (sum, sale) => sum + sale.effectiveTotal,
      );
      final collected = sales.fold(
        0.0,
        (sum, sale) => sum + _collectedFromSale(sale),
      );
      final credit = sales
          .where((sale) => sale.paymentMethod == AppStrings.creditPayment)
          .fold(
            0.0,
            (sum, sale) =>
                sum + (sale.effectiveTotal - sale.effectiveCollected),
          );
      final laterPayments = _laterPayments(debtProvider.movements, range);
      final profit = sales.fold(0.0, (sum, sale) => sum + sale.effectiveProfit);
      final itemCount = sales.fold<int>(
        0,
        (sum, sale) => sum + _effectiveItemCount(sale),
      );
      final clientCount = sales
          .map((sale) => sale.clientId ?? sale.clientName.toLowerCase())
          .toSet()
          .length;
      final summaryMetrics = <PeriodSummaryMetric>[
        PeriodSummaryMetric('Total vendido', _money(totalSold)),
        PeriodSummaryMetric('Cobrado por ventas', _money(collected)),
        PeriodSummaryMetric(
          'Fiado pendiente',
          _money(credit),
          valueColor: AppColors.dangerRed,
        ),
        PeriodSummaryMetric(
          'Abonos cobrados',
          _money(laterPayments),
          valueColor: AppColors.warningOrange,
        ),
        PeriodSummaryMetric('Cantidad de ventas', '${sales.length}'),
        PeriodSummaryMetric('Artículos vendidos', '$itemCount'),
        PeriodSummaryMetric('Clientes', '$clientCount'),
      ];
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
            Expanded(
              child: Row(
                children: [
                  Expanded(flex: 3, child: _buildList(sales, paidBySale)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PeriodSummaryPanel(
                      metrics: summaryMetrics,
                      rangeLabel:
                          '${_date(range.start)} → ${_date(range.end.subtract(const Duration(days: 1)))}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  '${sales.length} venta${sales.length == 1 ? '' : 's'} en ${_periodLabel()}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Ganancia estimada: ${_money(profit)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.successGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _buildHeader() => Row(
    children: [
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ventas', style: AppTextStyles.brandTitle),
            SizedBox(height: 3),
            Text(
              'Historial y registro de las ventas realizadas.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      OutlinedButton.icon(
        onPressed: _pickDate,
        icon: const Icon(Icons.calendar_today_outlined, size: 16),
        label: Text(
          _period == _SalesPeriod.custom ? 'Elegir rango' : _dateLabel(),
        ),
      ),
      const SizedBox(width: 8),
      PopupMenuButton<_SalesPeriod>(
        onSelected: (value) => value == _SalesPeriod.custom
            ? _pickRange()
            : setState(() => _period = value),
        itemBuilder: (_) => const [
          PopupMenuItem(value: _SalesPeriod.daily, child: Text('Diario')),
          PopupMenuItem(value: _SalesPeriod.weekly, child: Text('Semanal')),
          PopupMenuItem(value: _SalesPeriod.monthly, child: Text('Mensual')),
          PopupMenuItem(value: _SalesPeriod.yearly, child: Text('Anual')),
          PopupMenuItem(
            value: _SalesPeriod.custom,
            child: Text('Rango personalizado'),
          ),
        ],
        child: _menuSurface(Icons.tune_outlined, _periodLabel()),
      ),
    ],
  );
  Future<void> _pickDate() async {
    if (_period == _SalesPeriod.custom) return _pickRange();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _anchorDate,
    );
    if (picked != null) setState(() => _anchorDate = picked);
  }

  Future<void> _pickRange() async {
    final start = _customStart ?? _anchorDate;
    final end = _customEnd ?? start;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: start,
        end: end.isBefore(start) ? start : end,
      ),
    );
    if (picked == null) return;
    setState(() {
      _period = _SalesPeriod.custom;
      _customStart = picked.start;
      _customEnd = picked.end;
      _anchorDate = picked.start;
    });
  }

  Widget _buildMetrics(
    double sold,
    double collected,
    double credit,
    double laterPayments,
  ) => Row(
    children: [
      Expanded(
        child: _metric(
          'Total vendido',
          sold,
          Icons.receipt_long_outlined,
          AppColors.primary,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _metric(
          'Cobrado por ventas',
          collected,
          Icons.payments_outlined,
          AppColors.successGreen,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _metric(
          'Fiado generado',
          credit,
          Icons.account_balance_wallet_outlined,
          AppColors.dangerRed,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _metric(
          'Abonos cobrados',
          laterPayments,
          Icons.savings_outlined,
          AppColors.warningOrange,
        ),
      ),
    ],
  );
  Widget _metric(String label, double amount, IconData icon, Color color) =>
      Container(
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _money(amount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  Widget _buildFilters() => Row(
    children: [
      Expanded(
        child: ProductSearchBar(
          controller: _searchController,
          hintText: 'Buscar venta, cliente, producto o código...',
          onChanged: (_) {},
        ),
      ),
      const SizedBox(width: 8),
      PopupMenuButton<_SalesTypeFilter>(
        onSelected: (value) => setState(() => _typeFilter = value),
        itemBuilder: (_) => const [
          PopupMenuItem(value: _SalesTypeFilter.all, child: Text('Todas')),
          PopupMenuItem(
            value: _SalesTypeFilter.products,
            child: Text('Productos'),
          ),
          PopupMenuItem(
            value: _SalesTypeFilter.electronic,
            child: Text('Saldo electrónico'),
          ),
        ],
        child: _menuSurface(Icons.category_outlined, _typeLabel()),
      ),
      PopupMenuButton<_SalesPaymentFilter>(
        onSelected: (value) => setState(() => _paymentFilter = value),
        itemBuilder: (_) => const [
          PopupMenuItem(value: _SalesPaymentFilter.all, child: Text('Todos')),
          PopupMenuItem(
            value: _SalesPaymentFilter.cash,
            child: Text('Efectivo'),
          ),
          PopupMenuItem(
            value: _SalesPaymentFilter.card,
            child: Text('Tarjeta'),
          ),
          PopupMenuItem(
            value: _SalesPaymentFilter.transfer,
            child: Text('Transferencia'),
          ),
          PopupMenuItem(
            value: _SalesPaymentFilter.credit,
            child: Text('Fiado'),
          ),
        ],
        child: _menuSurface(Icons.filter_alt_outlined, _paymentLabel()),
      ),
    ],
  );
  String _typeLabel() {
    switch (_typeFilter) {
      case _SalesTypeFilter.all:
        return 'Todas';
      case _SalesTypeFilter.products:
        return 'Productos';
      case _SalesTypeFilter.electronic:
        return 'Saldo';
    }
  }

  String _paymentLabel() {
    switch (_paymentFilter) {
      case _SalesPaymentFilter.all:
        return 'Todos';
      case _SalesPaymentFilter.cash:
        return 'Efectivo';
      case _SalesPaymentFilter.card:
        return 'Tarjeta';
      case _SalesPaymentFilter.transfer:
        return 'Transferencia';
      case _SalesPaymentFilter.credit:
        return 'Fiado';
    }
  }

  Widget _menuSurface(IconData icon, String label) => Container(
    constraints: const BoxConstraints(minHeight: 42),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: AppColors.shadowColor,
          blurRadius: 7,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
  Widget _buildList(List<SaleRecord> sales, Map<String, double> paidBySale) =>
      HistoryTablePanel(
        title: 'Historial de ventas',
        icon: Icons.receipt_long_outlined,
        itemCount: sales.length,
        header: _buildListHeader(),
        emptyState: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: AppColors.textMuted,
              ),
              SizedBox(height: 10),
              Text(
                'No hay ventas en este período.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        itemBuilder: (_, index) => _saleRow(
          sales[index],
          paidBySale[sales[index].id] ?? sales[index].effectiveCollected,
        ),
      );
  Widget _buildListHeader() => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
    decoration: const BoxDecoration(
      color: AppColors.inputBackground,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: const Row(
      children: [
        SizedBox(
          width: 78,
          child: Text('Ticket', style: AppTextStyles.ticketLabel),
        ),
        SizedBox(
          width: 105,
          child: Text('Fecha / hora', style: AppTextStyles.ticketLabel),
        ),
        Expanded(
          flex: 2,
          child: Text('Cliente', style: AppTextStyles.ticketLabel),
        ),
        Expanded(child: Text('Artículos', style: AppTextStyles.ticketLabel)),
        SizedBox(
          width: 100,
          child: Text('Pago', style: AppTextStyles.ticketLabel),
        ),
        SizedBox(
          width: 185,
          child: Text('Estado / operación', style: AppTextStyles.ticketLabel),
        ),
        SizedBox(
          width: 100,
          child: Text(
            'Total',
            textAlign: TextAlign.right,
            style: AppTextStyles.ticketLabel,
          ),
        ),
        SizedBox(width: 26),
      ],
    ),
  );
  Widget _saleRow(SaleRecord sale, double paid) {
    final credit = sale.paymentMethod == AppStrings.creditPayment;
    final pending = credit
        ? (sale.effectiveTotal - paid).clamp(0, double.infinity).toDouble()
        : 0.0;
    final items = _effectiveItemCount(sale);
    final time =
        '${sale.createdAt.hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: () => _showDetails(sale, paid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              child: Text(
                '#${sale.ticketNumber}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(
              width: 105,
              child: Text(
                '${_date(sale.createdAt)}\n$time',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                sale.clientName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '$items artículo${items == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(width: 100, child: _paymentBadge(sale.paymentMethod)),
            SizedBox(width: 185, child: _statusOperationBadges(sale)),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(sale.effectiveTotal),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (credit)
                    Text(
                      pending <= .005
                          ? 'Pagada'
                          : 'Pendiente ${_money(pending)}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: pending <= .005
                            ? AppColors.successGreen
                            : AppColors.dangerRed,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusOperationBadges(SaleRecord sale) {
    final children = <Widget>[
      _saleBadge(
        sale.isAnnulled ? 'ANULADA' : 'COMPLETADA',
        sale.isAnnulled ? AppColors.dangerRed : AppColors.successGreen,
      ),
    ];
    final seen = <SaleOperationType>{};
    for (final operation in sale.operations) {
      if (seen.add(operation.type)) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '—',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ),
        );
        children.add(
          _saleBadge(
            operation.label,
            operation.type == SaleOperationType.change
                ? AppColors.primary
                : AppColors.warningOrange,
          ),
        );
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _saleBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(.10),
      border: Border.all(color: color.withOpacity(.35)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
    ),
  );
  Widget _paymentBadge(String method) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        method,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textDarkSecondary,
        ),
      ),
    ),
  );
  Future<void> _showDetails(SaleRecord sale, double paid) async =>
      SaleDetailDialog.show(
        context,
        sale: sale,
        paidAmount: paid,
        onPrint: () => _printSale(sale),
      );
  Future<void> _printSale(SaleRecord sale) async {
    final printer = context.read<PrinterProvider>();
    final printed = await printer.printSaleTicket(sale);
    if (!mounted) return;
    AppAlert.show(
      context,
      printed
          ? 'El ticket fue enviado a la impresora.'
          : (printer.errorMessage ?? 'No se pudo imprimir el ticket.'),
      title: printed ? 'Impresión completada' : 'No se pudo imprimir',
      type: printed ? AppAlertType.success : AppAlertType.warning,
    );
  }
}
