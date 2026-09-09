import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:stellar_pos/core/data/import_export/inventory_import_mapper.dart';
import 'package:stellar_pos/core/models/product.dart';

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
/// Excel row-to-product mapping belongs to [InventoryImportMapper]; this class
/// only handles workbook decoding and file persistence/report generation.
class InventoryFileService {
  static const List<String> headers = [
    'ID',
    'Producto',
    'Cant.',
    'Categoría',
    'Marca',
    'Distribuidora',
    'Precio de compra',
    'Precio de venta',
    'Stock',
    'Stock mínimo',
    'Stock máximo',
    'Código de barras',
    'Venta por grupos',
    'Unidades por grupo',
    'Precio por grupo',
  ];

  static const Set<String> supportedExcelExtensions =
      InventoryImportMapper.supportedExtensions;

  static Future<void> saveExcel(List<Product> products) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Inventario'];
    workbook.delete('Sheet1');
    workbook.setDefaultSheet('Inventario');

    for (var column = 0; column < headers.length; column++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[column]);
      cell.cellStyle = CellStyle(bold: true);
    }

    for (var rowIndex = 0; rowIndex < products.length; rowIndex++) {
      final p = products[rowIndex];
      final values = <CellValue>[
        TextCellValue(p.id),
        TextCellValue(p.name),
        TextCellValue(p.unit),
        TextCellValue(p.category),
        TextCellValue(p.brand),
        TextCellValue(p.department),
        DoubleCellValue(p.cost),
        DoubleCellValue(p.price),
        IntCellValue(p.stock),
        IntCellValue(p.minStock),
        IntCellValue(p.maxStock),
        TextCellValue(p.barcode),
        TextCellValue(p.hasGroupPricing ? 'Sí' : 'No'),
        IntCellValue(p.groupQuantity),
        DoubleCellValue(p.groupPrice),
      ];
      for (var column = 0; column < values.length; column++) {
        sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: rowIndex + 1,
          ),
        ).value = values[column];
      }
    }

    final bytes = workbook.save();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('No se pudo generar el archivo Excel.');
    }
    await FilePicker.saveFile(
      fileName: 'inventario_${_dateStamp()}.xlsx',
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
  }

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
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
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
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.grey600,
                    ),
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
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 9,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              border: pw.Border.all(color: PdfColors.grey300, width: .6),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Generación: ',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(_dateLabel(), style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(width: 28),
                pw.Text(
                  'Número de productos: ',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  '${products.length}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.Expanded(
                child: _summaryCard(
                  title: 'Costo total del inventario',
                  value: _money(totalInvestment),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _summaryCard(
                  title: 'Precio total del inventario',
                  value: _money(totalSales),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Resumen de inventario',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 7),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Producto',
              'Cant.',
              'Categoría',
              'Marca',
              'Distribuidora',
              'Compra',
              'Venta',
              'Stock',
              'Mín.',
              'Máx.',
              'Código',
            ],
            data: rows,
            headerHeight: 22,
            cellHeight: 20,
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
            cellStyle: const pw.TextStyle(
              fontSize: 6.5,
              color: PdfColors.grey800,
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 3,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColors.grey100,
            ),
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: .45,
            ),
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

  static pw.Widget _summaryCard({
    required String title,
    required String value,
  }) {
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
          pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
        ],
      ),
    );
  }

  static Future<InventoryImportResult> parseExcel(
    Uint8List bytes,
    String extension,
  ) async {
    final normalizedExtension = extension.toLowerCase().replaceFirst('.', '');
    if (!supportedExcelExtensions.contains(normalizedExtension)) {
      return const InventoryImportResult(
        products: [],
        errors: [
          'Formato no compatible. STELLAR POS acepta únicamente archivos Excel modernos .xlsx y .xlsm.',
        ],
      );
    }
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      return const InventoryImportResult(
        products: [],
        errors: [
          'El archivo no parece ser un libro Excel moderno válido (.xlsx/.xlsm).',
        ],
      );
    }

    try {
      final workbook = Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) {
        return const InventoryImportResult(
          products: [],
          errors: ['El archivo Excel no contiene ninguna hoja.'],
        );
      }

      final rows = workbook[workbook.tables.keys.first].rows;
      final result = InventoryImportMapper.mapRows(rows);
      return InventoryImportResult(
        products: result.products,
        errors: result.errors,
      );
    } catch (_) {
      return const InventoryImportResult(
        products: [],
        errors: [
          'No se pudo leer el libro Excel. Verifica que sea un .xlsx o .xlsm válido y que contenga la estructura de inventario esperada.',
        ],
      );
    }
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
