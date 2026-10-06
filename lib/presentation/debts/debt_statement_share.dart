import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';
import 'package:stellar_pos/presentation/debts/debt_statement_file_writer.dart';

class DebtStatementShare {
  static Future<void> show(BuildContext context, {required String clientName, required List<SaleRecord> sales, required DebtAccount account}) async {
    final creditSales = sales
        .where(
          (sale) =>
              sale.paymentMethod.toLowerCase() == 'fiado' &&
              !sale.isAnnulled &&
              sale.effectiveTotal > 0.005,
        )
        .toList(growable: false);
    if (creditSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay compras fiadas para compartir.')));
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) => _DebtStatementShareDialog(
        hostContext: context,
        clientName: clientName,
        sales: creditSales,
        account: account,
      ),
    );
  }
}

class _DebtStatementShareDialog extends StatefulWidget {
  final BuildContext hostContext;
  final String clientName;
  final List<SaleRecord> sales;
  final DebtAccount account;
  const _DebtStatementShareDialog({
    required this.hostContext,
    required this.clientName,
    required this.sales,
    required this.account,
  });
  @override State<_DebtStatementShareDialog> createState() => _DebtStatementShareDialogState();
}

class _DebtStatementShareDialogState extends State<_DebtStatementShareDialog> {
  final _boundaryKey = GlobalKey();
  late final List<_StatementPage> _pages;
  int _pageIndex = 0;
  bool _sharing = false;
  String _status = 'Preparando estado de cuenta';

  @override void initState() {
    super.initState();
    _pages = _buildPages(widget.sales);
    WidgetsBinding.instance.addPostFrameCallback((_) => _share());
  }

  List<_StatementPage> _buildPages(List<SaleRecord> sales) {
    final grouped = <DateTime, List<SaleItemRecord>>{};
    final sorted = [...sales]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final sale in sorted) {
      final day = DateTime(sale.createdAt.year, sale.createdAt.month, sale.createdAt.day);
      grouped.putIfAbsent(day, () => []).addAll(sale.items);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    // Keep a conservative row budget because the page also contains date
    // headers, table headers, product metadata, and (on the last page) totals.
    // Seven rows leaves enough vertical headroom inside the fixed 1800px canvas
    // even when a product name wraps to two lines.
    const maxRowsPerPage = 7;
    final pages = <_StatementPage>[];
    var current = <_StatementGroup>[];
    var rows = 0;
    void flush() {
      if (current.isEmpty) {
        return;
      }
      pages.add(_StatementPage(groups: current));
      current = <_StatementGroup>[];
      rows = 0;
    }
    for (final date in dates) {
      final items = grouped[date] ?? const <SaleItemRecord>[];
      var offset = 0;
      while (offset < items.length) {
        if (rows == maxRowsPerPage) {
          flush();
        }
        final available = maxRowsPerPage - rows;
        final take = (items.length - offset).clamp(0, available).toInt();
        current.add(_StatementGroup(date: date, items: items.sublist(offset, offset + take)));
        rows += take;
        offset += take;
        if (rows == maxRowsPerPage) {
          flush();
        }
      }
    }
    flush();
    return pages;
  }

  Future<void> _share() async {
    if (!mounted || _sharing) {
      return;
    }

    setState(() => _sharing = true);

    final files = <XFile>[];

    try {
      // Keep the existing 900x1800 canvas and 2.5x pixel ratio unchanged.
      // Native platforms receive real temporary PNG files instead of
      // XFile.fromData(), avoiding an extra temporary-file step inside
      // the macOS share sheet.
      for (var i = 0; i < _pages.length; i++) {
        _pageIndex = i;
        if (mounted) {
          setState(() {
            _status = _pages.length == 1
                ? 'Generando imagen del estado de cuenta'
                : 'Generando imagen ${i + 1} de ${_pages.length}';
          });
        }

        // Wait for the frame that contains the selected page to finish
        // painting. A fixed delay is not reliable on slower/debug macOS
        // renders and can leave toImage() waiting on an unpainted layer.
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;

        final boundary =
            _boundaryKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (boundary == null) {
          throw StateError('No se pudo preparar el estado de cuenta.');
        }

        if (mounted) {
          setState(() => _status = 'Capturando imagen ${i + 1} de ${_pages.length}');
        }

        final image = await boundary
            .toImage(pixelRatio: 2.5)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException(
                'La captura de la imagen tardó demasiado.',
              ),
            );

        if (mounted) {
          setState(() => _status = 'Codificando imagen ${i + 1} de ${_pages.length}');
        }

        final data = await image
            .toByteData(format: ui.ImageByteFormat.png)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException(
                'La conversión de la imagen a PNG tardó demasiado.',
              ),
            );
        image.dispose();

        if (data == null) {
          throw StateError('No se pudo generar una de las imágenes.');
        }

        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final fileName =
            'estado_cuenta_${_safeFileName(widget.clientName)}_${i + 1}.png';

        if (mounted) {
          setState(() => _status = 'Preparando archivo ${i + 1} de ${_pages.length}');
        }

        files.add(
          await createDebtStatementShareFile(
            bytes,
            fileName,
          ),
        );
      }

      if (!mounted) {
        await cleanupDebtStatementShareFiles(files);
        return;
      }

      if (mounted) {
        setState(() => _status = 'Abriendo opciones para compartir');
      }

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        Navigator.of(context).pop();
        await Future<void>.delayed(const Duration(milliseconds: 120));

        final status = await const MethodChannel(
          'stellar_pos/debt_statement_share',
        ).invokeMethod<String>(
          'shareFiles',
          <String, Object>{
            'paths': files.map((file) => file.path).toList(growable: false),
            'subject': 'Estado de cuenta - ${widget.clientName}',
          },
        );

        await cleanupDebtStatementShareFiles(files);

        final hostContext = widget.hostContext;
        if (!hostContext.mounted) {
          return;
        }

        switch (status) {
          case 'success':
            AppAlert.show(
              hostContext,
              _pages.length == 1
                  ? 'El estado de cuenta se compartió correctamente.'
                  : 'Se compartieron ${_pages.length} imágenes del estado de cuenta.',
              title: 'Estado de cuenta compartido',
              type: AppAlertType.success,
            );
          case 'dismissed':
            AppAlert.show(
              hostContext,
              'El estado de cuenta se generó correctamente, pero no se seleccionó una aplicación para compartirlo.',
              title: 'Compartir cancelado',
              type: AppAlertType.info,
            );
          default:
            AppAlert.show(
              hostContext,
              'No se pudo completar el proceso de compartir.',
              title: 'Error al compartir',
              type: AppAlertType.error,
            );
        }
        return;
      }

      // Other platforms continue using share_plus. macOS uses a native
      // NSSharingServicePicker implemented in the Runner so the picker
      // lifecycle and temporary files remain under our control.
      // The native macOS share picker must be presented by the main app
      // window, not while this Flutter showDialog route is still modal.
      // Presenting it from the loading dialog can leave the native picker
      // visible without its sharing options and keep this dialog spinning.
      final hostBox = widget.hostContext.findRenderObject() as RenderBox?;
      final origin = hostBox != null && hostBox.hasSize
          ? Rect.fromCenter(
              center: hostBox.localToGlobal(
                Offset(hostBox.size.width / 2, hostBox.size.height / 2),
              ),
              width: 1,
              height: 1,
            )
          : Rect.fromLTWH(0, 0, 1, 1);

      // Close the Flutter loading dialog before invoking the native share UI.
      Navigator.of(context).pop();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final shareResult = await SharePlus.instance.share(
        ShareParams(
          files: files,
          subject: 'Estado de cuenta - ${widget.clientName}',
          sharePositionOrigin: origin,
          fileNameOverrides: files
              .map((file) => file.name)
              .whereType<String>()
              .toList(growable: false),
        ),
      );

      await cleanupDebtStatementShareFiles(files);

      if (!widget.hostContext.mounted) {
        return;
      }

      switch (shareResult.status) {
        case ShareResultStatus.success:
          AppAlert.show(
            widget.hostContext,
            _pages.length == 1
                ? 'El estado de cuenta se compartió correctamente.'
                : 'Se compartieron ${_pages.length} imágenes del estado de cuenta.',
            title: 'Estado de cuenta compartido',
            type: AppAlertType.success,
          );
        case ShareResultStatus.dismissed:
          AppAlert.show(
            widget.hostContext,
            'El estado de cuenta se generó correctamente, pero no se seleccionó una aplicación para compartirlo.',
            title: 'Compartir cancelado',
            type: AppAlertType.info,
          );
        case ShareResultStatus.unavailable:
          AppAlert.show(
            widget.hostContext,
            'El estado de cuenta se generó correctamente. El sistema no informó qué aplicación recibió el contenido.',
            title: 'Estado de cuenta generado',
            type: AppAlertType.success,
          );
      }
    } catch (error) {
      await cleanupDebtStatementShareFiles(files);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      AppAlert.show(
        context,
        'No se pudo generar o compartir el estado de cuenta: $error',
        title: 'Error al generar estado de cuenta',
        type: AppAlertType.error,
      );
    }
  }

  String _safeFileName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ _-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? 'cliente' : sanitized;
  }

  @override Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 250),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.dialogRadius), border: Border.all(color: AppColors.border)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2.5),
                SizedBox(height: 16),
                Text('Preparando estado de cuenta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        Positioned(
          left: -1200,
          top: 0,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: _DebtStatementImage(
              clientName: widget.clientName,
              sales: widget.sales,
              account: widget.account,
              groups: _pages[_pageIndex].groups,
              pageNumber: _pageIndex + 1,
              pageCount: _pages.length,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatementPage {
  final List<_StatementGroup> groups;
  const _StatementPage({required this.groups});
}

class _StatementGroup {
  final DateTime date;
  final List<SaleItemRecord> items;
  const _StatementGroup({required this.date, required this.items});
}

class _DebtStatementImage extends StatelessWidget {
  final String clientName;
  final List<SaleRecord> sales;
  final DebtAccount account;
  final List<_StatementGroup> groups;
  final int pageNumber;
  final int pageCount;
  const _DebtStatementImage({required this.clientName, required this.sales, required this.account, required this.groups, required this.pageNumber, required this.pageCount});

  String _money(double value) => '\u0024${value.toStringAsFixed(2)}';
  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override Widget build(BuildContext context) {
    final subtotal = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.effectiveTotal,
    );
    final last = pageNumber == pageCount;
    return Material(
      color: Colors.white,
      child: SizedBox(
        width: 900,
        height: 1800,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 48, 56, 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pageNumber == 1) ...[
                const Text('Tienda El Edén', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                const Text('ESTADO DE CUENTA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.black54)),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE2E2E2)),
                const SizedBox(height: 18),
                _infoRow('Contacto', clientName),
                _infoRow('Fecha de emisión', _date(DateTime.now())),
                _infoRow('Método de pago', 'Fiado'),
                const SizedBox(height: 22),
              ],
              for (final group in groups) ...[
                _dateHeader(group.date),
                const SizedBox(height: 8),
                _tableHeader(),
                for (final item in group.items) _itemRow(item),
                const SizedBox(height: 24),
              ],
              const Expanded(child: SizedBox()),
              if (last) ...[
                const Divider(color: Color(0xFFD6D6D6)),
                const SizedBox(height: 20),
                _totalRow(
                  'Deuda pendiente',
                  subtotal,
                  strong: true,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                _totalRow(
                  'Abonos anteriores aplicados',
                  (subtotal - account.remaining).clamp(0, subtotal).toDouble(),
                  color: AppColors.successGreen,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Parte de los abonos anteriores ya aplicada a estas compras.',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(top: 18),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFD6D6D6))),
                  ),
                  child: _totalRow(
                    'Restante por pagar',
                    account.remaining,
                    strong: true,
                    large: true,
                    color: AppColors.dangerRed,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E2E2)),
              const SizedBox(height: 10),
              Center(child: Text('$pageNumber D $pageCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54))),
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
    final displayUnitPrice = item.quantity > 0
        ? item.lineSubtotal / item.quantity
        : item.unitPrice;
    final calculatedDiscount = (item.lineSubtotal - item.lineTotal)
        .clamp(0, double.infinity)
        .toDouble();
    final displayDiscount = item.discount > calculatedDiscount
        ? item.discount
        : calculatedDiscount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEAEAEA)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                if (!item.isElectronicBalance && item.unit.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.unit.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 11,
            child: Text(
              item.quantity.toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 15,
            child: Text(
              _money(displayUnitPrice),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 13,
            child: Text(
              _money(displayDiscount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 15,
            child: Text(
              _money(item.lineTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool strong = false, bool large = false, Color? color}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(fontSize: large ? 20 : 14, fontWeight: strong ? FontWeight.w900 : FontWeight.w700, color: color ?? Colors.black87)),
      Text(_money(value), style: TextStyle(fontSize: large ? 22 : 15, fontWeight: FontWeight.w900, color: color ?? Colors.black87)),
    ],
  );
}
