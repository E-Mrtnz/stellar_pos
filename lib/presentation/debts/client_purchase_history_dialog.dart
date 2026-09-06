import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/sale.dart';

class ClientPurchaseHistoryDialog extends StatelessWidget {
  final String clientName;
  final List<SaleRecord> sales;

  const ClientPurchaseHistoryDialog({
    super.key,
    required this.clientName,
    required this.sales,
  });

  static Future<void> show(
    BuildContext context, {
    required String clientName,
    required List<SaleRecord> sales,
  }) {
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
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
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
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 19),
                  ),
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

  @override
  Widget build(BuildContext context) {
    final date = '${sale.createdAt.day.toString().padLeft(2, '0')}/'
        '${sale.createdAt.month.toString().padLeft(2, '0')}/${sale.createdAt.year}';
    final hour = sale.createdAt.hour % 12 == 0 ? 12 : sale.createdAt.hour % 12;
    final period = sale.createdAt.hour >= 12 ? 'PM' : 'AM';
    final time = '${hour.toString().padLeft(2, '0')}:${sale.createdAt.minute.toString().padLeft(2, '0')} $period';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withAlpha(16),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text('FIADO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.dangerRed)),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text('#${sale.ticketNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              Text('\$${sale.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.dangerRed)),
            ],
          ),
          const SizedBox(height: 6),
          Text('$date · $time', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 9),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 7),
          ...sale.items.map((item) => _SaleItemRow(item: item)),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Total de la deuda generada: \$${sale.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textPrimary)),
                Text(item.unit, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
              ],
            ),
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
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: bytes == null
          ? const Icon(Icons.image_outlined, size: 18, color: AppColors.textMuted)
          : Image.memory(bytes!, fit: BoxFit.cover),
    );
  }
}

Uint8List? _decodeImage(String value) {
  if (value.trim().isEmpty) return null;
  try {
    return base64Decode(value.contains(',') ? value.split(',').last : value);
  } catch (_) {
    return null;
  }
}
