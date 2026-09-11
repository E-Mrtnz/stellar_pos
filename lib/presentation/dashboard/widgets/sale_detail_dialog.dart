import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/date_aware_sales_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sale_detail_dialog_legacy.dart' as legacy;

class SaleDetailDialog extends StatelessWidget {
  static ValueChanged<SaleRecord>? get editHandler =>
      legacy.SaleDetailDialog.editHandler;
  static set editHandler(ValueChanged<SaleRecord>? value) =>
      legacy.SaleDetailDialog.editHandler = value;
  static ValueChanged<SaleRecord>? get returnHandler =>
      legacy.SaleDetailDialog.returnHandler;
  static set returnHandler(ValueChanged<SaleRecord>? value) =>
      legacy.SaleDetailDialog.returnHandler = value;
  static ValueChanged<SaleRecord>? get changeHandler =>
      legacy.SaleDetailDialog.changeHandler;
  static set changeHandler(ValueChanged<SaleRecord>? value) =>
      legacy.SaleDetailDialog.changeHandler = value;

  final SaleRecord sale;
  final Future<void> Function() onPrint;
  final double? paidAmount;

  const SaleDetailDialog({
    super.key,
    required this.sale,
    required this.onPrint,
    this.paidAmount,
  });

  static Future<void> show(
    BuildContext context, {
    required SaleRecord sale,
    required Future<void> Function() onPrint,
    double? paidAmount,
  }) {
    return showDialog(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Consumer<SalesProvider>(
          builder: (context, _, __) => SaleDetailDialog(
            sale: sale,
            onPrint: onPrint,
            paidAmount: paidAmount,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _selectDate(BuildContext context) async {
    final salesProvider = context.read<SalesProvider>();
    final dateAware = salesProvider as DateAwareSalesProvider;
    final today = DateTime.now();
    final lastDate = DateTime(today.year, today.month, today.day);
    final initialDate = sale.createdAt.isAfter(lastDate) ? lastDate : sale.createdAt;

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: lastDate,
      helpText: 'Modificar fecha de venta',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (selected == null || !context.mounted) return;

    try {
      await dateAware.updateSaleDate(saleId: sale.id, date: selected);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la fecha: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        legacy.SaleDetailDialog(
          sale: sale,
          onPrint: onPrint,
          paidAmount: paidAmount,
        ),
        Positioned(
          top: 142,
          left: 125,
          right: 20,
          height: 24,
          child: Container(
            color: AppColors.cardBackground,
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  _formatDate(sale.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationThickness: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
