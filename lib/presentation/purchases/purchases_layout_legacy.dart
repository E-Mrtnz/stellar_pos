import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/purchases_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/presentation/widgets/product_search_bar.dart';

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTimeRange get _range {
    if (_period == _Period.custom && _customRange != null) {
      return DateTimeRange(
        start: DateTime(
          _customRange!.start.year,
          _customRange!.start.month,
          _customRange!.start.day,
        ),
        end: DateTime(
          _customRange!.end.year,
          _customRange!.end.month,
          _customRange!.end.day,
          23,
          59,
          59,
          999,
        ),
      );
    }

    final day = DateTime(_anchor.year, _anchor.month, _anchor.day);

    switch (_period) {
      case _Period.daily:
        return DateTimeRange(
          start: day,
          end: DateTime(day.year, day.month, day.day, 23, 59, 59, 999),
        );
      case _Period.weekly:
        final start = day.subtract(
          Duration(days: day.weekday - DateTime.monday),
        );
        return DateTimeRange(
          start: start,
          end: DateTime(
            start.year,
            start.month,
            start.day + 6,
            23,
            59,
            59,
            999,
          ),
        );
      case _Period.monthly:
        return DateTimeRange(
          start: DateTime(day.year, day.month),
          end: DateTime(day.year, day.month + 1, 0, 23, 59, 59, 999),
        );
      case _Period.yearly:
        return DateTimeRange(
          start: DateTime(day.year),
          end: DateTime(day.year + 1, 1, 0, 23, 59, 59, 999),
        );
      case _Period.custom:
        return DateTimeRange(
          start: DateTime(day.year, day.month),
          end: DateTime(day.year, day.month + 1, 0, 23, 59, 59, 999),
        );
    }
  }

  List<PurchaseRecord> _purchases(PurchasesProvider provider) {
    final range = _range;
    final query = _query.trim().toLowerCase();

    final list = provider.purchases.where((purchase) {
      if (purchase.arrivalAt.isBefore(range.start) ||
          purchase.arrivalAt.isAfter(range.end)) {
        return false;
      }

      if (query.isEmpty) return true;

      return purchase.distributorName.toLowerCase().contains(query) ||
          purchase.invoiceNumber.toLowerCase().contains(query);
    }).toList();

    list.sort((a, b) => b.arrivalAt.compareTo(a.arrivalAt));
    return list;
  }

  List<SaleRecord> _sales(SalesProvider provider) {
    final range = _range;

    return provider.sales
        .where(
          (sale) =>
              !sale.createdAt.isBefore(range.start) &&
              !sale.createdAt.isAfter(range.end),
        )
        .toList();
  }

  Future<void> _choosePeriod(_Period value) async {
    if (value == _period && value != _Period.custom) return;

    setState(() => _period = value);

    if (value == _Period.custom) {
      await _chooseDateRange();
    }
  }

  Future<void> _chooseDate() async {
    switch (_period) {
      case _Period.monthly:
        final picked = await showDialog<DateTime>(
          context: context,
          builder: (_) => _MonthYearPicker(initialDate: _anchor),
        );
        if (picked != null) {
          setState(() => _anchor = picked);
        }
        return;
      case _Period.yearly:
        final picked = await showDialog<int>(
          context: context,
          builder: (_) => _YearPicker(initialYear: _anchor.year),
        );
        if (picked != null) {
          setState(() => _anchor = DateTime(picked, 1));
        }
        return;
      case _Period.daily:
        final picked = await showDialog<DateTime>(
          context: context,
          builder: (_) => _SingleDatePicker(initialDate: _anchor),
        );
        if (picked != null) {
          setState(() => _anchor = picked);
        }
        return;
      case _Period.weekly:
        final picked = await showDialog<DateTime>(
          context: context,
          builder: (_) => _SingleDatePicker(initialDate: _anchor),
        );
        if (picked != null) {
          setState(() => _anchor = picked);
        }
        return;
      case _Period.custom:
        await _chooseDateRange();
        return;
    }
  }

  Future<void> _chooseDateRange() async {
    final picked = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DateRangePickerDialog(
        initialRange: _customRange,
        initialDate: _anchor,
      ),
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
        _anchor = picked.start;
      });
    }
  }

  String _periodName() {
    switch (_period) {
      case _Period.daily:
        return 'Diario';
      case _Period.weekly:
        return 'Semanal';
      case _Period.monthly:
        return 'Mensual';
      case _Period.yearly:
        return 'Anual';
      case _Period.custom:
        return 'Rango personalizado';
    }
  }

  String _dateName() {
    if (_period == _Period.custom && _customRange != null) {
      return '${_date(_customRange!.start)} → ${_date(_customRange!.end)}';
    }

    if (_period == _Period.monthly) {
      return '${_month(_anchor.month)} ${_anchor.year}';
    }

    if (_period == _Period.yearly) {
      return '${_anchor.year}';
    }

    final range = _range;
    return _period == _Period.daily
        ? _date(_anchor)
        : '${_date(range.start)} → ${_date(range.end)}';
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _month(int month) {
    return const [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ][month - 1];
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final purchaseProvider = context.watch<PurchasesProvider>();
    final salesProvider = context.watch<SalesProvider>();
    final purchases = _purchases(purchaseProvider);
    final sales = _sales(salesProvider);

    final purchaseTotal = purchases.fold<double>(
      0,
      (sum, purchase) => sum + purchase.total,
    );
    final salesTotal = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );
    final grossProfit = sales.fold<double>(
      0,
      (sum, sale) =>
          sum +
          sale.items.fold<double>(
            0,
            (inner, item) =>
                inner +
                ((item.unitPrice - item.cost) * item.quantity) -
                item.discount,
          ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              children: [
                _filters(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        'Compras',
                        _money(purchaseTotal),
                        Icons.shopping_bag_outlined,
                        AppColors.dangerRed,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        'Ventas',
                        _money(salesTotal),
                        Icons.point_of_sale_outlined,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        'Ganancia bruta',
                        _money(grossProfit),
                        Icons.trending_up_outlined,
                        AppColors.successGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: _history(purchases)),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _summary(purchases, sales, grossProfit),
                      ),
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
              heroTag: 'purchase_fab',
              shape: const CircleBorder(),
              backgroundColor: AppColors.primary,
              tooltip: 'Nueva compra',
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('Nueva compra'),
                    content: Text(
                      'Aquí conectaremos el formulario de ingreso cuando definamos el segundo boceto.',
                    ),
                    actions: [],
                  ),
                );
              },
              child: const Icon(
                Icons.add_shopping_cart_outlined,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Row(
      children: [
        Expanded(
          child: ProductSearchBar(
            controller: _searchController,
            hintText: 'Buscar proveedor o factura...',
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(width: 10),
        _PeriodButton(
          value: _period,
          label: _periodName(),
          onSelected: _choosePeriod,
        ),
        const SizedBox(width: 8),
        _FilterButton(
          label: _dateName(),
          icon: Icons.calendar_today_outlined,
          onPressed: _chooseDate,
        ),
      ],
    );
  }

  Widget _history(List<PurchaseRecord> purchases) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              const Text(
                'Historial de compras',
                style: AppTextStyles.sectionTitle,
              ),
              const Spacer(),
              Text(
                '${purchases.length}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: purchases.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 70),
                    itemCount: purchases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _PurchaseCard(purchases[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summary(
    List<PurchaseRecord> purchases,
    List<SaleRecord> sales,
    double profit,
  ) {
    final items = purchases.fold<int>(
      0,
      (sum, purchase) => sum + purchase.itemCount,
    );
    final suppliers = purchases
        .map((purchase) => purchase.distributorName.toLowerCase())
        .toSet()
        .length;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Resumen del período',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: 12),
          _Metric(
            'Compras',
            _money(
              purchases.fold<double>(
                0,
                (sum, purchase) => sum + purchase.total,
              ),
            ),
          ),
          _Metric(
            'Ventas',
            _money(
              sales.fold<double>(0, (sum, sale) => sum + sale.total),
            ),
          ),
          _Metric(
            'Ganancia bruta',
            _money(profit),
            AppColors.successGreen,
          ),
          const Divider(height: 22, color: AppColors.border),
          _Metric('Cantidad de compras', '${purchases.length}'),
          _Metric('Productos comprados', '$items'),
          _Metric('Proveedores', '$suppliers'),
          const Spacer(),
          Text(
            '${_date(_range.start)} → ${_date(_range.end)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final _Period value;
  final String label;
  final ValueChanged<_Period> onSelected;

  const _PeriodButton({
    required this.value,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Period>(
      tooltip: 'Agrupar por período',
      onSelected: onSelected,
      offset: const Offset(0, 8),
      color: AppColors.cardBackground,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      itemBuilder: (_) => [
        _item(_Period.daily, 'Diario'),
        _item(_Period.weekly, 'Semanal'),
        _item(_Period.monthly, 'Mensual'),
        _item(_Period.yearly, 'Anual'),
        _item(_Period.custom, 'Rango personalizado'),
      ],
      child: _FilterSurface(
        icon: Icons.calendar_view_month_outlined,
        label: label,
        trailing: Icons.keyboard_arrow_down_rounded,
      ),
    );
  }

  PopupMenuItem<_Period> _item(_Period item, String text) {
    return PopupMenuItem<_Period>(
      value: item,
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: item == value ? FontWeight.w600 : FontWeight.w500,
                color: item == value
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          if (item == value)
            const Icon(
              Icons.check_rounded,
              size: 17,
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _FilterButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppDimensions.searchFieldRadius),
      child: _FilterSurface(icon: icon, label: label),
    );
  }
}

class _FilterSurface extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? trailing;

  const _FilterSurface({
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.searchFieldRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 3),
            Icon(trailing, size: 18, color: AppColors.textSecondary),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _SummaryCard(this.label, this.value, this.icon, this.accent);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final PurchaseRecord purchase;

  const _PurchaseCard(this.purchase);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _PurchaseDetail(purchase),
        ),
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchase.distributorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      purchase.invoiceNumber.isEmpty
                          ? 'Sin número de factura'
                          : 'Factura ${purchase.invoiceNumber}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Llegada: ${_date(purchase.arrivalAt)}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${purchase.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    purchase.paymentMethod,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${purchase.itemCount} productos',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _PurchaseDetail extends StatelessWidget {
  final PurchaseRecord purchase;

  const _PurchaseDetail(this.purchase);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detalle de compra',
                          style: AppTextStyles.sectionTitle,
                        ),
                        Text(
                          purchase.distributorName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _Info(
                      'Factura',
                      purchase.invoiceNumber.isEmpty
                          ? '—'
                          : purchase.invoiceNumber,
                    ),
                  ),
                  Expanded(
                    child: _Info(
                      'Fecha de llegada',
                      _date(purchase.arrivalAt),
                    ),
                  ),
                  Expanded(
                    child: _Info(
                      'Forma de pago',
                      purchase.paymentMethod,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: purchase.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 7),
                itemBuilder: (_, index) => _PurchaseItem(purchase.items[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Spacer(),
                  const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 28),
                  Text(
                    '\$${purchase.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;

  const _Info(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PurchaseItem extends StatelessWidget {
  final PurchaseItemRecord item;

  const _PurchaseItem(this.item);

  @override
  Widget build(BuildContext context) {
    final bytes = _image(item.imageData);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: bytes == null
                ? const Icon(
                    Icons.image_outlined,
                    color: AppColors.textMuted,
                  )
                : Image.memory(bytes, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 45,
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.unit,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${item.unitCost.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 18),
          Text(
            '\$${item.total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static Uint8List? _image(String value) {
    if (value.trim().isEmpty) return null;

    try {
      return base64Decode(
        value.contains(',') ? value.split(',').last : value,
      );
    } catch (_) {
      return null;
    }
  }
}

class _MonthYearPicker extends StatefulWidget {
  final DateTime initialDate;

  const _MonthYearPicker({required this.initialDate});

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late int _year;
  late int _month;

  static const _months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _month = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, minWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 21,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${_fullMonth(_month)} $_year',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Año anterior',
                    onPressed: () => setState(() => _year--),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Año siguiente',
                    onPressed: () => setState(() => _year++),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: 2.35,
                ),
                itemCount: 12,
                itemBuilder: (_, index) {
                  final month = index + 1;
                  final selected = month == _month;
                  return InkWell(
                    onTap: () => Navigator.pop(
                      context,
                      DateTime(_year, month),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        _months[index],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fullMonth(int month) {
    return const [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ][month - 1];
  }
}

class _YearPicker extends StatefulWidget {
  final int initialYear;

  const _YearPicker({required this.initialYear});

  @override
  State<_YearPicker> createState() => _YearPickerState();
}

class _YearPickerState extends State<_YearPicker> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(12, (index) => _year - 5 + index);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, minWidth: 390),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Seleccionar año',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _year -= 12),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _year += 12),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: 2.2,
                ),
                itemCount: years.length,
                itemBuilder: (_, index) {
                  final year = years[index];
                  final selected = year == widget.initialYear;
                  return InkWell(
                    onTap: () => Navigator.pop(context, year),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '$year',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleDatePicker extends StatefulWidget {
  final DateTime initialDate;

  const _SingleDatePicker({required this.initialDate});

  @override
  State<_SingleDatePicker> createState() => _SingleDatePickerState();
}

class _SingleDatePickerState extends State<_SingleDatePicker> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _month = DateTime(_selected.year, _selected.month);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470, minWidth: 390),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _calendarHeader(),
              const SizedBox(height: 10),
              _calendarGrid(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calendarHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_fullMonth(_month.month)} ${_month.year}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: () => setState(
            () => _month = DateTime(_month.year, _month.month - 1),
          ),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          onPressed: () => setState(
            () => _month = DateTime(_month.year, _month.month + 1),
          ),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _calendarGrid() {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final leading = (firstDay.weekday - DateTime.monday) % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final totalCells = ((leading + days + 6) ~/ 7) * 7;

    const weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Column(
      children: [
        Row(
          children: weekdays
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (_, index) {
            final dayNumber = index - leading + 1;
            if (dayNumber < 1 || dayNumber > days) return const SizedBox();

            final date = DateTime(_month.year, _month.month, dayNumber);
            final selected = _sameDay(date, _selected);

            return InkWell(
              onTap: () => setState(() => _selected = date),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _fullMonth(int month) {
    return const [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ][month - 1];
  }
}

class _DateRangePickerDialog extends StatefulWidget {
  final DateTimeRange? initialRange;
  final DateTime initialDate;

  const _DateRangePickerDialog({
    required this.initialRange,
    required this.initialDate,
  });

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  late DateTime _leftMonth;
  late DateTime _rightMonth;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();

    final base = widget.initialRange?.start ?? widget.initialDate;
    _leftMonth = DateTime(base.year, base.month);
    _rightMonth = DateTime(base.year, base.month + 1);
    _start = widget.initialRange?.start;
    _end = widget.initialRange?.end;
  }

  DateTimeRange? get _result {
    if (_start == null || _end == null) return null;
    final start = _start!;
    final end = _end!;
    return DateTimeRange(
      start: start.isBefore(end) ? start : end,
      end: start.isBefore(end) ? end : start,
    );
  }

  void _select(DateTime date) {
    setState(() {
      if (_start == null || _end != null) {
        _start = date;
        _end = null;
        return;
      }

      if (date.isBefore(_start!)) {
        _end = _start;
        _start = date;
      } else {
        _end = date;
      }
    });
  }

  void _move(int months) {
    setState(() {
      _leftMonth = DateTime(_leftMonth.year, _leftMonth.month + months);
      _rightMonth = DateTime(_leftMonth.year, _leftMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, minWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.date_range_outlined,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Seleccionar rango',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _rangeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Mes anterior',
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(child: _monthPanel(_leftMonth)),
                  const SizedBox(width: 18),
                  Expanded(child: _monthPanel(_rightMonth)),
                  IconButton(
                    tooltip: 'Mes siguiente',
                    onPressed: () => _move(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _result == null
                        ? null
                        : () => Navigator.pop(context, _result),
                    child: const Text('Aplicar rango'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _rangeLabel {
    if (_start == null) return 'Selecciona una fecha inicial';
    if (_end == null) return '${_date(_start!)} → …';
    return '${_date(_result!.start)} → ${_date(_result!.end)}';
  }

  Widget _monthPanel(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final leading = (firstDay.weekday - DateTime.monday) % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = ((leading + days + 6) ~/ 7) * 7;

    const weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Column(
      children: [
        Text(
          '${_fullMonth(month.month)} ${month.year}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: weekdays
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 5),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (_, index) {
            final dayNumber = index - leading + 1;
            if (dayNumber < 1 || dayNumber > days) return const SizedBox();

            final date = DateTime(month.year, month.month, dayNumber);
            final isStart = _sameDay(date, _start);
            final isEnd = _sameDay(date, _end);
            final inRange = _start != null &&
                _end != null &&
                !date.isBefore(_result!.start) &&
                !date.isAfter(_result!.end);

            return InkWell(
              onTap: () => _select(date),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isStart || isEnd
                      ? AppColors.primary
                      : inRange
                          ? AppColors.primary.withAlpha(28)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isStart || isEnd
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isStart || isEnd
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _fullMonth(int month) {
    return const [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ][month - 1];
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Metric(this.label, this.value, [this.valueColor]);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 34,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 9),
          Text(
            'No hay compras registradas en este período.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
