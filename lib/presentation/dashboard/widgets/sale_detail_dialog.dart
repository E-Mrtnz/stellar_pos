import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/sale.dart';

class SaleDetailDialog extends StatelessWidget {
  final SaleRecord sale;
  final Future<bool> Function() onPrint;
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
    required Future<bool> Function() onPrint,
    double? paidAmount,
  }) {
    return showDialog(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SaleDetailDialog(sale: sale, onPrint: onPrint, paidAmount: paidAmount),
      ),
    );
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  double get _paid => (paidAmount ?? sale.received).clamp(0, sale.total).toDouble();
  double get _initialPayment => sale.received.clamp(0, sale.total).toDouble();
  double get _laterPayment => (_paid - _initialPayment).clamp(0, double.infinity).toDouble();
  double get _pending => (sale.total - _paid).clamp(0, double.infinity).toDouble();

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Detalle de venta', style: AppTextStyles.sectionTitle),
                  ),
                  Text(
                    '#${sale.ticketNumber}',
                    style: AppTextStyles.ticketValue,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 19),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 14),
                    _buildItemsTable(),
                    const SizedBox(height: 14),
                    _buildTotals(),
                    const SizedBox(height: 14),
                    _buildPaymentInfo(),
                    const SizedBox(height: 14),
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Gracias por su compra',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Código de ticket: ${sale.ticketNumber}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await onPrint();
                      },
                      icon: const Icon(Icons.print_outlined, size: 17),
                      label: const Text('Imprimir ticket'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(38),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('STELLAR POS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        const Text('MI TIENDA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 9),
        _infoRow('N.º de ticket', '#${sale.ticketNumber}'),
        _infoRow('Fecha', _formatDate(sale.createdAt)),
        _infoRow('Hora', _formatTime(sale.createdAt)),
        _infoRow('Cliente', sale.clientName),
      ],
    );
  }

  Widget _buildItemsTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 35, child: Text('Cant.', style: AppTextStyles.ticketLabel)),
                SizedBox(width: 42, child: Text('Img.', style: AppTextStyles.ticketLabel)),
                Expanded(child: Text('Descripción', style: AppTextStyles.ticketLabel)),
                SizedBox(width: 70, child: Text('P. Unit.', textAlign: TextAlign.right, style: AppTextStyles.ticketLabel)),
                SizedBox(width: 70, child: Text('Dcto.', textAlign: TextAlign.right, style: AppTextStyles.ticketLabel)),
                SizedBox(width: 75, child: Text('Total', textAlign: TextAlign.right, style: AppTextStyles.ticketLabel)),
              ],
            ),
          ),
          ...sale.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 35, child: Text('${item.quantity}', style: AppTextStyles.ticketValue)),
                  _thumbnail(item.imageData),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  SizedBox(width: 70, child: Text('\$${item.unitPrice.toStringAsFixed(2)}', textAlign: TextAlign.right, style: AppTextStyles.ticketValue)),
                  SizedBox(width: 70, child: Text('\$${item.discount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: AppTextStyles.ticketValue)),
                  SizedBox(width: 75, child: Text('\$${item.lineTotal.toStringAsFixed(2)}', textAlign: TextAlign.right, style: AppTextStyles.ticketValue)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(String value) {
    if (value.trim().isNotEmpty) {
      try {
        final raw = value.contains(',') ? value.substring(value.indexOf(',') + 1) : value;
        final bytes = base64Decode(raw);
        return Container(
          width: 42,
          height: 42,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.border)),
          child: Image.memory(bytes, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.border)),
      child: const Icon(Icons.image_outlined, size: 19, color: AppColors.textMuted),
    );
  }

  Widget _buildTotals() {
    return Column(
      children: [
        _summaryRow('Subtotal', sale.subtotal),
        _summaryRow('Descuento', sale.discountAmount),
        if (sale.cardFeeAmount > 0) _summaryRow('Cargo tarjeta', sale.cardFeeAmount),
        const Divider(height: 16, color: AppColors.border),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total', style: AppTextStyles.totalLabel),
            Text('\$${sale.total.toStringAsFixed(2)}', style: AppTextStyles.totalValue),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          _infoRow('Forma de pago', sale.paymentMethod),
          if (sale.paymentMethod == AppStrings.creditPayment) ...[
            _summaryRow('Pago inicial', _initialPayment),
            _summaryRow('Abonos posteriores', _laterPayment),
            _summaryRow('Total cobrado', _paid),
            _summaryRow('Saldo pendiente', _pending),
          ] else if (sale.paymentMethod == AppStrings.cashPayment) ...[
            _summaryRow('Recibido', sale.received),
            _summaryRow('Cambio', sale.change),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.ticketLabel),
          Text('\$${value.toStringAsFixed(2)}', style: AppTextStyles.ticketValue),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 105, child: Text(label, style: AppTextStyles.ticketLabel)),
          Expanded(child: Text(value, style: AppTextStyles.ticketValue)),
        ],
      ),
    );
  }
}
