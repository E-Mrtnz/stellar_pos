import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';

class DebtStatementShare {
  static Future<void> show(
    BuildContext context, {
    required String clientName,
    required List<SaleRecord> sales,
    required DebtAccount account,
  }) async {
    final creditSales = sales.where((sale) =>
      sale.paymentMethod.toLowerCase() == 'fiado' &&
      !sale.isAnnulled && sale.effectiveTotal > 0.005,
    ).toList(growable: false);

    if (creditSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay compras fiadas para compartir.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) => _DebtStatementShareDialog(
        clientName: clientName,
        sales: creditSales,
        account: account,
      ),
    );
  }
}

class _DebtStatementShareDialog extends StatefulWidget {
  final String clientName;
  final List<SaleRecord> sales;
  final DebtAccount account;

  const _DebtStatementShareDialog({
    required this.clientName,
    required this.sales,
    required this.account,
  });

  @override
  State<_DebtStatementShareDialog> createState() => _DebtStatementShareDialogState();
}

class _DebtStatementShareDialogState extends State<_DebtStatementShareDialog> {
  final _boundaryKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _share());
  }

  Future<void> _share() async {
    if (!mounted || _sharing) return;
    setState(() => _sharing = true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final renderObject = _boundaryKey.currentContext?.findRenderObject();
      final boundary = renderObject as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('No se pudo preparar el estado de cuenta.');

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw StateError('No se pudo generar la imagen.');

      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      final originBox = context.findRenderObject() as RenderBox?;
      final origin = originBox == null
          ? null
          : originBox.localToGlobal(Offset.zero) & originBox.size;

      if (!mounted) return;
      Navigator.of(context).pop();
      AppAlert.show(
        context,
        'La imagen del estado de cuenta se generó correctamente.',
        title: 'Estado de cuenta generado',
        type: AppAlertType.success,
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(bytes),
              mimeType: 'image/png',
            ),
          ],
          fileNameOverrides: [
            'estado_cuenta_${_safeFileName(widget.clientName)}.png',
          ],
          title: 'Estado de cuenta - ${widget.clientName}',
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el estado de cuenta: $error')),
      );
    }
  }

  String _safeFileName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    return normalized.isEmpty ? 'cliente' : normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 250),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 16),
                  Text(
                    'Preparando estado de cuenta',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Generando la imagen para compartir por WhatsApp...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: -1200,
            top: 0,
            child: _statementForCapture(),
          ),
        ],
      ),
    );
  }

  Widget _statementForCapture() => RepaintBoundary(
    key: _boundaryKey,
    child: _DebtStatementImage(
      clientName: widget.clientName,
      sales: widget.sales,
      account: widget.account,
    ),
  );
}

class _DebtStatementImage extends StatelessWidget {
  final String clientName;
  final List<SaleRecord> sales;
  final DebtAccount account;

  const _DebtStatementImage({
    required this.clientName,
    required this.sales,
    required this.account,
  });

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<SaleItemRecord>>{};
    final sortedSales = [...sales]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final sale in sortedSales) {
      final day = DateTime(sale.createdAt.year, sale.createdAt.month, sale.createdAt.day);
      grouped.putIfAbsent(day, () => []).addAll(sale.items);
    }

    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final subtotal = sales.fold<double>(0, (sum, sale) => sum + sale.effectiveTotal);

    return Material(
      color: Colors.white,
      child: SizedBox(
        width: 900,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 48, 56, 52),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('STELLAR POS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text('ESTADO DE CUENTA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.black54)),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E2E2)),
              const SizedBox(height: 18),
              _infoRow('Contacto', clientName),
              _infoRow('Fecha de emisión', _date(DateTime.now())),
              _infoRow('Método de pago', 'Fiado'),
              const SizedBox(height: 22),
              for (final date in dates) ...[
                _dateHeader(date),
                const SizedBox(height: 8),
                _tableHeader(),
                for (final item in grouped[date]!) _itemRow(item),
                const SizedBox(height: 24),
              ],
              const Divider(color: Color(0xFFD6D6D6)),
              const SizedBox(height: 20),
              _totalRow('Subtotal', subtotal, strong: true),
              const SizedBox(height: 16),
              _totalRow('Total abonado', account.totalPaid),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.only(top: 18),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFD6D6D6)))),
                child: _totalRow('Restante por pagar', account.remaining, strong: true, large: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54))),
      Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _dateHeader(DateTime date) => Container(
    margin: const EdgeInsets.only(top: 2),
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
    decoration: BoxDecoration(color: const Color(0xFFF4F6FA), borderRadius: BorderRadius.circular(8)),
    child: Text(_date(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
  );

  Widget _tableHeader() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Row(children: [
      Expanded(flex: 40, child: Text('Productos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54))),
      Expanded(flex: 11, child: Text('Cantidad', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54))),
      Expanded(flex: 15, child: Text('P. unitario', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54))),
      Expanded(flex: 13, child: Text('Descuento', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54))),
      Expanded(flex: 15, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54))),
    ]),
  );

  Widget _itemRow(SaleItemRecord item) {
    final displayUnitPrice = item.hasGroupPricing ? item.lineTotal : item.unitPrice;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEAEAEA)))),
      child: Row(children: [
        Expanded(flex: 40, child: Text(item.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
        Expanded(flex: 11, child: Text('${item.quantity}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
        Expanded(flex: 15, child: Text(_money(displayUnitPrice), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
        Expanded(flex: 13, child: Text(_money(item.discount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
        Expanded(flex: 15, child: Text(_money(item.lineTotal), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _totalRow(String label, double value, {bool strong = false, bool large = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(fontSize: large ? 20 : 14, fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
      Text(_money(value), style: TextStyle(fontSize: large ? 22 : 15, fontWeight: FontWeight.w900)),
    ],
  );
}