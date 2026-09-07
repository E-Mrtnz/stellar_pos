import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/presentation/debts/edit_credit_sale_dialog.dart';

class ClientPurchaseHistoryDialog extends StatelessWidget {
  final String clientName;
  final List<SaleRecord> sales;

  const ClientPurchaseHistoryDialog({super.key, required this.clientName, required this.sales});

  static Future<void> show(BuildContext context, {required String clientName, required List<SaleRecord> sales}) {
    return showDialog(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClientPurchaseHistoryDialog(clientName: clientName, sales: sales),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [...sales]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
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
                  const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Historial de compras', style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 2),
                        Text(clientName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(tooltip: 'Cerrar', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 19)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: ordered.isEmpty
                  ? const Padding(padding: EdgeInsets.all(40), child: Text('Este cliente todavía no tiene compras a fiado.', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: ordered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _SaleHistoryCard(sale: ordered[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleHistoryCard extends StatelessWidget {
  final SaleRecord sale;
  const _SaleHistoryCard({required this.sale});

  Future<void> _edit(BuildContext context) async {
    final updatedItems = await EditCreditSaleDialog.show(context, sale: sale);
    if (updatedItems == null || !context.mounted) return;

    final subtotal = updatedItems.fold<double>(0, (sum, item) => sum + item.unitPrice * item.quantity);
    final oldRate = sale.subtotal <= 0 ? 0 : sale.discountAmount / sale.subtotal;
    final newTotal = subtotal - subtotal * oldRate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar cambios'),
        content: Text(
          'La venta #${sale.ticketNumber} se actualizará con los productos seleccionados.\n\n'
          'Total anterior: \$${sale.total.toStringAsFixed(2)}\n'
          'Nuevo total: \$${newTotal.toStringAsFixed(2)}\n\n'
          '¿Deseas aplicar estos cambios?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      context.read<SalesProvider>().updateSale(
        saleId: sale.id,
        updatedItems: updatedItems,
        productProvider: context.read<ProductProvider>(),
        electronicBalanceProvider: context.read<ElectronicBalanceProvider>(),
      );
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La venta fue actualizada correctamente.')));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is StateError ? error.message : 'No se pudo actualizar la venta.')));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar venta fiada'),
        content: Text(
          '¿Seguro que deseas eliminar la venta #${sale.ticketNumber} de ${sale.clientName}?\n\n'
          'La venta desaparecerá del historial y de las cuentas por cobrar, y se devolverán al inventario los productos que formaban parte de ella.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dangerRed),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final deleted = context.read<SalesProvider>().deleteSale(
      saleId: sale.id,
      productProvider: context.read<ProductProvider>(),
      electronicBalanceProvider: context.read<ElectronicBalanceProvider>(),
    );
    if (!context.mounted) return;
    if (deleted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La venta fue eliminada correctamente.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo eliminar la venta.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = '${sale.createdAt.day.toString().padLeft(2, '0')}/${sale.createdAt.month.toString().padLeft(2, '0')}/${sale.createdAt.year}';
    final hour = sale.createdAt.hour % 12 == 0 ? 12 : sale.createdAt.hour % 12;
    final period = sale.createdAt.hour >= 12 ? 'PM' : 'AM';
    final time = '${hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')} $period';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.dangerRed.withAlpha(16), borderRadius: BorderRadius.circular(7)), child: const Text('FIADO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.dangerRed))),
              const SizedBox(width: 9),
              Expanded(child: Text('#${sale.ticketNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              Text('\$${sale.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.dangerRed)),
              const SizedBox(width: 5),
              IconButton(tooltip: 'Editar venta', onPressed: () => _edit(context), icon: const Icon(Icons.edit_outlined, size: 18), visualDensity: VisualDensity.compact),
              IconButton(tooltip: 'Eliminar venta', onPressed: () => _delete(context), icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.dangerRed), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 6),
          Text('$date · $time', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 9),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 7),
          ...sale.items.map((item) => _SaleItemRow(item: item)),
          const SizedBox(height: 5),
          Align(alignment: Alignment.centerRight, child: Text('Total de la deuda generada: \$${sale.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textPrimary)), Text(item.unit, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: AppColors.textMuted))])),
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
        width: 42,
        height: 42,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: bytes == null ? const Icon(Icons.image_outlined, size: 18, color: AppColors.textMuted) : Image.memory(bytes!, fit: BoxFit.cover),
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
