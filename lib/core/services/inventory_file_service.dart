import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/services/inventory_excel_service.dart';

/// Result exposed by the legacy file-service API.
///
/// Kept here so existing presentation callers do not need to migrate in the
/// same change that extracts the Excel mapping logic.
class InventoryImportResult {
  final List<Product> products;
  final List<String> errors;

  const InventoryImportResult({required this.products, required this.errors});

  bool get hasErrors => errors.isNotEmpty;
}

/// Coordinates inventory file input/output.
///
/// Excel-specific work is delegated to [InventoryExcelService]. PDF report
/// generation remains here for backwards compatibility with the presentation
/// layer while that UI is migrated incrementally.
class InventoryFileService {
  static const List<String> headers = InventoryExcelService.headers;

  static const Set<String> supportedExcelExtensions =
      InventoryExcelService.supportedExtensions;

  static Future<void> saveExcel(List<Product> products) =>
      InventoryExcelService.save(products);

  static Future<void> savePdf(List<Product> products) async {
    final document = pw.Document();
    final totalInvestment = products.fold<double>(
      0,
      (total, p) => total + p.cost * p.stock,
    );
    final totalSales = products.fold<double>(
      0,
      (total, p) => total + p.price * p.stock,
    );
    final rows = products
        .map(
          (p) => <String>[
            p.name,
            p.unit,
            p.category,
            p.brand,
            p.department,
            _money(p.cost),
            _money(p.price),
            p.stock.toString(),
            p.minStock.toString(),
            p.maxStock.toString(),
            p.barcode,
          ],
        )
        .toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 24),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'STELLAR POS • Reporte de inventario',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Reporte de inventario',
                    style: pw.TextStyle(
                      fontSize: 21,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Control y valoración del inventario actual',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.Text(
                _dateLabel(),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              border: pw.Border.all(color: PdfColors.grey300, width: .6),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Generación: ',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                ),
                pw.Text(_dateLabel(), style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(width: 28),
                pw.Text(
                  'Número de productos: ',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                ),
                pw.Text('${products.length}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _summaryCard(title: 'Costo total del inventario', value: _money(totalInvestment)),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _summaryCard(title: 'Precio total del inventario', value: _money(totalSales)),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Resumen de inventario',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
          ),
          pw.SizedBox(height: 7),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Producto', 'Cant.', 'Categoría', 'Marca', 'Distribuidora',
              'Compra', 'Venta', 'Stock', 'Mín.', 'Máx.', 'Código',
            ],
            data: rows,
            headerHeight: 22,
            cellHeight: 20,
            headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
            cellStyle: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey800),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: .45),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.0),
              1: pw.FlexColumnWidth(.9),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1.5),
              5: pw.FlexColumnWidth(.8),
              6: pw.FlexColumnWidth(.8),
              7: pw.FlexColumnWidth(.7),
              8: pw.FlexColumnWidth(.55),
              9: pw.FlexColumnWidth(.55),
              10: pw.FlexColumnWidth(1.2),
            },
          ),
        ],
      ),
    );

    final bytes = await document.save();
    await FilePicker.saveFile(
      fileName: 'inventario_${_dateStamp()}.pdf',
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
  }

  static Future<InventoryImportResult> parseExcel(
    Uint8List bytes,
    String extension,
  ) async {
    final result = await InventoryExcelService.parse(bytes, extension);
    return InventoryImportResult(products: result.products, errors: result.errors);
  }

  static pw.Widget _summaryCard({required String title, required String value}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey400, width: .7),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(title, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
        ],
      ),
    );
  }

  static String _money(double value) => '\$${value.toStringAsFixed(2)}';

  static String _dateStamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  }

  static String _dateLabel() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }
}
