import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/debt_provider.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/presentation/debts/edit_credit_sale_dialog.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';

class ClientPurchaseHistoryDialog extends StatefulWidget {
  final String clientName;
  final List<SaleRecord> sales;

  const ClientPurchaseHistoryDialog({super.key, required this.clientName, required this.sales});

  static Future<void> show(BuildContext context, {required String clientName, required List<SaleRecord> sales}) => showDialog(
        context: context,
        barrierColor: AppColors.overlayBackground,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClientPurchaseHistoryDialog(clientName: clientName, sales: sales),
        ),
      );

  Map<String, double> _paidBySale(DebtProvider provider) {
    final oldestFirst = [...sales]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    var paymentPool = provider.paidForClient(oldestFirst.isEmpty ? '' : oldestFirst.first.clientId ?? '');
    final result = <String, double>{};
    for (final sale in oldestFirst) {
      final paid = paymentPool.clamp(0, sale.total).toDouble();
      result[sale.id] = paid;
      paymentPool = (paymentPool - paid).clamp(0, double.infinity).toDouble();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [...sales]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final paidBySale = _paidBySale(context.watch<DebtProvider>());
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Historial de compras', style: AppTextStyles.sectionTitle),
                      const SizedBox(height: 2),
                      Text(clientName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 19)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: ordered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('Este cliente todavía no tiene compras a fiado.', style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: ordered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) => _SaleHistoryCard(sale: ordered[index], paidAmount: paidBySale[ordered[index].id] ?? 0),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleHistoryCard extends StatefulWidget {
  final SaleRecord sale;
  final double paidAmount;
  const _SaleHistoryCard({required this.sale, required this.paidAmount});
  @override
  State<_SaleHistoryCard> createState() => _SaleHistoryCardState();
}

class _SaleHistoryCardState extends State<_SaleHistoryCard> {
  bool _expanded = false;

  Future<void> _edit() async {
    final updatedItems = await EditCreditSaleDialog.show(context, sale: widget.sale);
    if (updatedItems == null || !mounted) return;
    try {
      context.read<SalesProvider>().updateSale(
        saleId: widget.sale.id,
        updatedItems: updatedItems,
        productProvider: context.read<ProductProvider>(),
        electronicBalanceProvider: context.read<ElectronicBalanceProvider>(),
      );
      AppAlert.show(context, 'La venta fue actualizada correctamente.', title: 'Venta actualizada', type: AppAlertType.success);
    } catch (error) {
      AppAlert.show(context, error is StateError ? error.message : 'No se pudo actualizar la venta.', title: 'Error al actualizar', type: AppAlertType.error);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (dialogContext) => _ConfirmDialog(
        title: 'Eliminar venta fiada',
        icon: Icons.delete_outline_rounded,
        danger: true,
        message: '¿Seguro que deseas eliminar la venta #${widget.sale.ticketNumber} de ${widget.sale.clientName}?',
        details: const ['La venta desaparecerá del historial y de las cuentas por cobrar.', 'Los productos físicos volverán al inventario.'],
        confirmLabel: 'Eliminar',
        onConfirm: () => Navigator.pop(dialogContext, true),
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = context.read<SalesProvider>().deleteSale(
      saleId: widget.sale.id,
      productProvider: context.read<ProductProvider>(),
      electronicBalanceProvider: context.read<ElectronicBalanceProvider>(),
    );
    if (!mounted) return;
    AppAlert.show(
      context,
      deleted ? 'La venta fue eliminada correctamente.' : 'No se pudo eliminar la venta.',
      title: deleted ? 'Venta eliminada' : 'Error al eliminar',
      type: deleted ? AppAlertType.success : AppAlertType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final remaining = (sale.total - widget.paidAmount).clamp(0, double.infinity).toDouble();
    final isPaid = remaining <= 0.005;
    final isPartial = widget.paidAmount > 0.005 && !isPaid;
    final statusColor = isPaid ? AppColors.successGreen : isPartial ? AppColors.warningOrange : AppColors.dangerRed;
    final statusLabel = isPaid ? 'PAGADA' : isPartial ? 'ABONO PARCIAL' : 'PENDIENTE';
    final date = '${sale.createdAt.day.toString().padLeft(2, '0')}/${sale.createdAt.month.toString().padLeft(2, '0')}/${sale.createdAt.year}';
    final hour = sale.createdAt.hour % 12 == 0 ? 12 : sale.createdAt.hour % 12;
    final period = sale.createdAt.hour >= 12 ? 'PM' : 'AM';
    final time = '${hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')} $period';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _expanded ? statusColor.withAlpha(85) : AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withAlpha(18), borderRadius: BorderRadius.circular(6)),
                  child: Text(statusLabel, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: statusColor)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('#${sale.ticketNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 1),
                    Text('$date · $time', style: const TextStyle(fontSize: 8, color: AppColors.textMuted)),
                  ]),
                ),
                Text('\$${sale.total.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isPaid ? AppColors.successGreen : AppColors.dangerRed)),
                IconButton(
                  tooltip: isPaid ? 'Venta pagada' : 'Editar venta',
                  onPressed: isPaid ? null : _edit,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Eliminar venta',
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.dangerRed),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Abonado: \$${widget.paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 8, color: AppColors.textSecondary)),
                const SizedBox(width: 9),
                Text('Restante: \$${remaining.toStringAsFixed(2)}', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: statusColor)),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 2),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                children: [
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 4),
                  ...sale.items.map((item) => _SaleItemRow(item: item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleItemRow extends StatelessWidget {
  final SaleItemRecord item;
  const _SaleItemRow({required this.item});
  @override
  Widget build(BuildContext context) {
    final bytes = _decodeImage(item.imageData);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _ProductThumbnail(bytes: bytes),
          const SizedBox(width: 8),
          SizedBox(width: 34, child: Text('${item.quantity}x', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textPrimary)),
              Text(item.unit, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
            ]),
          ),
          Text('\$${item.lineTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  final Uint8List? bytes;
  const _ProductThumbnail({required this.bytes});
  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.border)),
        child: bytes == null ? const Icon(Icons.image_outlined, size: 17, color: AppColors.textMuted) : Image.memory(bytes!, fit: BoxFit.cover),
      );
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;
  final List<String> details;
  final String confirmLabel;
  final bool danger;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _ConfirmDialog({required this.title, required this.icon, required this.message, required this.details, required this.confirmLabel, required this.onConfirm, required this.onCancel, this.danger = false});

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: (danger ? AppColors.dangerRed : AppColors.primary).withAlpha(16), borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: danger ? AppColors.dangerRed : AppColors.primary, size: 21),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title, style: AppTextStyles.sectionTitle)),
                    IconButton(onPressed: onCancel, icon: const Icon(Icons.close, size: 19)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(message, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                ...details.map((detail) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(detail, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: onCancel, child: const Text('Cancelar')),
                    const SizedBox(width: 7),
                    FilledButton(onPressed: onConfirm, style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.dangerRed) : null, child: Text(confirmLabel)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

Uint8List? _decodeImage(String value) {
  if (value.trim().isEmpty) return null;
  try {
    return base64Decode(value.contains(',') ? value.split(',').last : value);
  } catch (_) {
    return null;
  }
}
