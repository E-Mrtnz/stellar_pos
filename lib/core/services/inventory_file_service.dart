import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:stellar_pos/core/models/product.dart';

class InventoryImportResult {
  final List<Product> products;
  final List<String> errors;

  const InventoryImportResult({
    required this.products,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// Handles inventory files using the modern Office Open XML Excel format.
///
/// Supported input formats:
/// - .xlsx: standard modern Excel workbook.
/// - .xlsm: macro-enabled modern Excel workbook. STELLAR POS reads the
///   workbook data; VBA/macros are not imported or preserved.
///
/// Legacy binary .xls files are intentionally not supported.
class InventoryFileService {
  static const List<String> headers = [
    'ID',
    'Producto',
    'Unidad',
    'Categoría',
    'Distribuidora',
    'Precio de compra',
    'Precio de venta',
    'Stock',
    'Stock mínimo',
    'Stock máximo',
    'Código de barras',
  ];

  static const Set<String> supportedExcelExtensions = {'xlsx', 'xlsm'};

  static Future<void> saveExcel(List<Product> products) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Inventario'];

    for (var column = 0; column < headers.length; column++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[column]);
      cell.cellStyle = CellStyle(bold: true);
    }

    for (var rowIndex = 0; rowIndex < products.length; rowIndex++) {
      final product = products[rowIndex];
      final values = <CellValue>[
        TextCellValue(product.id),
        TextCellValue(product.name),
        TextCellValue(product.unit),
        TextCellValue(product.category),
        TextCellValue(product.department),
        DoubleCellValue(product.cost),
        DoubleCellValue(product.price),
        IntCellValue(product.stock),
        IntCellValue(product.minStock),
        IntCellValue(product.maxStock),
        TextCellValue(product.barcode),
      ];

      for (var column = 0; column < values.length; column++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: rowIndex + 1,
          ),
        );
        cell.value = values[column];
      }
    }

    final bytes = workbook.save();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('No se pudo generar el archivo Excel.');
    }

    await FileSaver.instance.saveFile(
      name: 'inventario_${_dateStamp()}',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static Future<void> savePdf(List<Product> products) async {
    final document = pw.Document();
    final rows = products
        .map(
          (product) => <String>[
            product.name,
            product.unit,
            product.category,
            product.department,
            _money(product.cost),
            _money(product.price),
            product.stock.toString(),
            product.minStock.toString(),
            product.maxStock.toString(),
            product.barcode,
          ],
        )
        .toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Inventario',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(_dateLabel(), style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: const [
              'Producto',
              'Unidad',
              'Categoría',
              'Distribuidora',
              'Compra',
              'Venta',
              'Stock',
              'Mín.',
              'Máx.',
              'Código',
            ],
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: 0.5,
            ),
          ),
        ],
      ),
    );

    final bytes = await document.save();
    await FileSaver.instance.saveFile(
      name: 'inventario_${_dateStamp()}',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
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

      final sheetName = workbook.tables.keys.first;
      final rows = workbook[sheetName].rows;
      if (rows.isEmpty) {
        return const InventoryImportResult(
          products: [],
          errors: ['La hoja de Excel está vacía.'],
        );
      }

      final headerMap = _buildHeaderMap(rows.first);
      if (!headerMap.containsKey('producto')) {
        return const InventoryImportResult(
          products: [],
          errors: [
            'No se encontró la columna "Producto". Usa el archivo exportado por STELLAR POS como plantilla.',
          ],
        );
      }

      final products = <Product>[];
      final errors = <String>[];

      for (var index = 1; index < rows.length; index++) {
        final row = rows[index];
        if (_rowIsEmpty(row)) continue;

        final excelRow = index + 1;
        final name = _read(row, headerMap, 'producto').trim();
        if (name.isEmpty) {
          errors.add('Fila $excelRow: falta el nombre del producto.');
          continue;
        }

        final cost = _readDouble(row, headerMap, 'precio de compra');
        final price = _readDouble(row, headerMap, 'precio de venta');
        final stock = _readInt(row, headerMap, 'stock');
        final minStock = _readInt(row, headerMap, 'stock mínimo');
        final maxStock = _readInt(row, headerMap, 'stock máximo');

        if (cost < 0 || price < 0 || stock < 0 || minStock < 0 || maxStock < 0) {
          errors.add(
            'Fila $excelRow: los valores numéricos no pueden ser negativos.',
          );
          continue;
        }

        products.add(
          Product(
            id: _read(row, headerMap, 'id').trim(),
            name: name,
            unit: _read(row, headerMap, 'unidad').trim(),
            category: _read(row, headerMap, 'categoría').trim(),
            department: _read(row, headerMap, 'distribuidora').trim(),
            cost: cost,
            price: price,
            stock: stock,
            minStock: minStock,
            maxStock: maxStock,
            barcode: _read(row, headerMap, 'código de barras').trim(),
          ),
        );
      }

      if (products.isEmpty && errors.isEmpty) {
        errors.add('No se encontraron productos para importar.');
      }

      return InventoryImportResult(products: products, errors: errors);
    } catch (_) {
      return const InventoryImportResult(
        products: [],
        errors: [
          'No se pudo leer el libro Excel. Verifica que sea un .xlsx o .xlsm válido y que contenga la estructura de inventario esperada.',
        ],
      );
    }
  }

  static Map<String, int> _buildHeaderMap(List<dynamic> row) {
    final map = <String, int>{};
    for (var index = 0; index < row.length; index++) {
      final normalized = _normalizeHeader(_cellText(row[index]));
      if (normalized.isNotEmpty) map[normalized] = index;
    }
    return map;
  }

  static String _normalizeHeader(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');

    const aliases = <String, String>{
      'nombre': 'producto',
      'producto': 'producto',
      'cant': 'stock',
      'cant.': 'stock',
      'cantidad': 'stock',
      'cant disponible': 'stock',
      'cant. disponible': 'stock',
      'stock': 'stock',
      'costo unitario': 'precio de compra',
      'costo': 'precio de compra',
      'precio unitario': 'precio de venta',
      'p. venta': 'precio de venta',
      'precio venta': 'precio de venta',
      'precio de venta': 'precio de venta',
      'distribuidora': 'distribuidora',
      'distribuidor': 'distribuidora',
      'proveedor': 'distribuidora',
      'codigo de barras': 'codigo de barras',
      'codigo': 'codigo de barras',
      'barcode': 'codigo de barras',
      'id': 'id',
      'unidad': 'unidad',
      'categoria': 'categoria',
      'stock minimo': 'stock minimo',
      'stock maximo': 'stock maximo',
      'minimo': 'stock minimo',
      'maximo': 'stock maximo',
    };

    return aliases[normalized] ?? normalized;
  }

  static String _read(
    List<dynamic> row,
    Map<String, int> headers,
    String key,
  ) {
    final index = headers[_normalizeHeader(key)];
    if (index == null || index >= row.length) return '';
    return _cellText(row[index]);
  }

  static double _readDouble(
    List<dynamic> row,
    Map<String, int> headers,
    String key,
  ) {
    final value = _read(row, headers, key).replaceAll(',', '.');
    return double.tryParse(value) ?? 0;
  }

  static int _readInt(
    List<dynamic> row,
    Map<String, int> headers,
    String key, {
    int fallback = 0,
  }) {
    final value = _read(row, headers, key).replaceAll(',', '.');
    return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
  }

  static String _cellText(dynamic cell) {
    if (cell == null) return '';

    final value = cell.value;
    if (value == null) return '';

    return switch (value) {
      TextCellValue(:final value) => value.toString(),
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value.toString(),
      BoolCellValue(:final value) => value.toString(),
      DateCellValue(:final year, :final month, :final day) =>
        '$year-$month-$day',
      DateTimeCellValue(:final year, :final month, :final day, :final hour,
        :final minute, :final second, :final millisecond) =>
        '$year-$month-$day $hour:$minute:$second.$millisecond',
      TimeCellValue(:final hour, :final minute, :final second, :final millisecond) =>
        '$hour:$minute:$second.$millisecond',
      FormulaCellValue(:final formula) => formula.toString(),
      _ => value.toString(),
    };
  }

  static bool _rowIsEmpty(List<dynamic> row) {
    return row.every((cell) => _cellText(cell).trim().isEmpty);
  }

  static String _money(double value) => '\$${value.toStringAsFixed(2)}';

  static String _dateStamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  }

  static String _dateLabel() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }
}
