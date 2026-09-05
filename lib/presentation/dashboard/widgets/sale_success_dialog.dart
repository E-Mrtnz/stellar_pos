import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sale_detail_dialog.dart';

class SaleSuccessDialog extends StatelessWidget {
  final SaleRecord sale;
  final Future<bool> Function() onPrint;

  const SaleSuccessDialog({
    super.key,
    required this.sale,
    required this.onPrint,
  });

  static Future<void> show(
    BuildContext context, {
    required SaleRecord sale,
    required Future<bool> Function() onPrint,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.overlayBackground,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SaleSuccessDialog(sale: sale, onPrint: onPrint),
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppColors.successGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 42),
              ),
              const SizedBox(height: 18),
              const Text(
                'Venta realizada con éxito',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    _infoRow('N.º de ticket', '#${sale.ticketNumber}'),
                    _infoRow('Método de pago', sale.paymentMethod),
                    _infoRow('Fecha', _formatDate(sale.createdAt)),
                    _infoRow('Hora', _formatTime(sale.createdAt)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: AppTextStyles.totalLabel),
                        Text(
                          '\$${sale.total.toStringAsFixed(2)}',
                          style: AppTextStyles.totalValue.copyWith(fontSize: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await onPrint();
                  },
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Imprimir ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              TextButton(
                onPressed: () {
                  SaleDetailDialog.show(
                    context,
                    sale: sale,
                    onPrint: onPrint,
                  );
                },
                child: const Text('Ver detalle de venta'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Salir'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.ticketLabel),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.ticketValue,
            ),
          ),
        ],
      ),
    );
  }
}
