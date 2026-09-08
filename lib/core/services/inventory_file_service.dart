import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:stellar_pos/core/models/product.dart';

class InventoryImportResult {
  final List<Product> products;
  final List<String> errors;
  const InventoryImportResult({required this.products, required this.errors});
  bool get hasErrors => errors.isNotEmpty;
}

class InventoryFileService {
  static const List<String> headers = [
    'ID', 'Producto', 'Cant.', 'Categoría', 'Marca', 'Distribuidora', 'Precio de compra', 'Precio de venta', 'Stock', 'Stock mínimo', 'Stock máximo', 'Código de barras',
    'Venta por grupos', 'Unidades por grupo', 'Precio por grupo',
  ];
  static const Set<String> supportedExcelExtensions = {'xlsx', 'xlsm'};

  static Future<void> saveExcel(List<Product> products) async {
    final workbook = Excel.createExcel(); final sheet = workbook['Inventario']; workbook.delete('Sheet1'); workbook.setDefaultSheet('Inventario');
    for (var column = 0; column < headers.length; column++) { final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0)); cell.value = TextCellValue(headers[column]); cell.cellStyle = CellStyle(bold: true); }
    for (var rowIndex = 0; rowIndex < products.length; rowIndex++) {
      final p = products[rowIndex]; final values = <CellValue>[
        TextCellValue(p.id), TextCellValue(p.name), TextCellValue(p.unit), TextCellValue(p.category), TextCellValue(p.brand), TextCellValue(p.department), DoubleCellValue(p.cost), DoubleCellValue(p.price), IntCellValue(p.stock), IntCellValue(p.minStock), IntCellValue(p.maxStock), TextCellValue(p.barcode), TextCellValue(p.hasGroupPricing ? 'Sí' : 'No'), IntCellValue(p.groupQuantity), DoubleCellValue(p.groupPrice),
      ];
      for (var column = 0; column < values.length; column++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowIndex + 1)).value = values[column];
    }
    final bytes = workbook.save(); if (bytes == null || bytes.isEmpty) throw StateError('No se pudo generar el archivo Excel.');
    await FilePicker.saveFile(fileName: 'inventario_${_dateStamp()}.xlsx', bytes: Uint8List.fromList(bytes), type: FileType.custom, allowedExtensions: const ['xlsx']);
  }

  static Future<void> savePdf(List<Product> products) async {
    final document = pw.Document();
    final totalInvestment = products.fold<double>(0, (total, p) => total + p.cost * p.stock);
    final totalSales = products.fold<double>(0, (total, p) => total + p.price * p.stock);
    final rows = products.map((p) => <String>[p.name, p.unit, p.category, p.brand, p.department, _money(p.cost), _money(p.price), p.stock.toString(), p.minStock.toString(), p.maxStock.toString(), p.barcode]).toList();
    document.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 24), footer: (context) => pw.Padding(padding: const pw.EdgeInsets.only(top: 8), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('STELLAR POS • Reporte de inventario', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)), pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600))])), build: (_) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('Reporte de inventario', style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)), pw.SizedBox(height: 4), pw.Text('Control y valoración del inventario actual', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600))]), pw.Text(_dateLabel(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))]),
      pw.SizedBox(height: 14), pw.Container(width: double.infinity, padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)), border: pw.Border.all(color: PdfColors.grey300, width: .6)), child: pw.Row(children: [pw.Text('Generación: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)), pw.Text(_dateLabel(), style: const pw.TextStyle(fontSize: 8)), pw.SizedBox(width: 28), pw.Text('Número de productos: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)), pw.Text('${products.length}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))])),
      pw.SizedBox(height: 12), pw.Row(children: [pw.Expanded(child: _summaryCard(title: 'Costo total del inventario', value: _money(totalInvestment))), pw.SizedBox(width: 12), pw.Expanded(child: _summaryCard(title: 'Precio total del inventario', value: _money(totalSales)))]), pw.SizedBox(height: 16), pw.Text('Resumen de inventario', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)), pw.SizedBox(height: 7),
      pw.TableHelper.fromTextArray(headers: const ['Producto', 'Cant.', 'Categoría', 'Marca', 'Distribuidora', 'Compra', 'Venta', 'Stock', 'Mín.', 'Máx.', 'Código'], data: rows, headerHeight: 22, cellHeight: 20, headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900), cellStyle: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey800), cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3), headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300), oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100), border: pw.TableBorder.all(color: PdfColors.grey400, width: .45), columnWidths: const {0: pw.FlexColumnWidth(2.0), 1: pw.FlexColumnWidth(.9), 2: pw.FlexColumnWidth(1.2), 3: pw.FlexColumnWidth(1.2), 4: pw.FlexColumnWidth(1.5), 5: pw.FlexColumnWidth(.8), 6: pw.FlexColumnWidth(.8), 7: pw.FlexColumnWidth(.7), 8: pw.FlexColumnWidth(.55), 9: pw.FlexColumnWidth(.55), 10: pw.FlexColumnWidth(1.2)})
    ]));
    final bytes = await document.save(); await FilePicker.saveFile(fileName: 'inventario_${_dateStamp()}.pdf', bytes: Uint8List.fromList(bytes), type: FileType.custom, allowedExtensions: const ['pdf']);
  }

  static pw.Widget _summaryCard({required String title, required String value}) => pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: pw.BoxDecoration(color: PdfColors.white, border: pw.Border.all(color: PdfColors.grey400, width: .7), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [pw.Text(title, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)), pw.SizedBox(height: 4), pw.Text(value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900))]));

  static Future<InventoryImportResult> parseExcel(Uint8List bytes, String extension) async {
    final normalizedExtension = extension.toLowerCase().replaceFirst('.', '');
    if (!supportedExcelExtensions.contains(normalizedExtension)) return const InventoryImportResult(products: [], errors: ['Formato no compatible. STELLAR POS acepta únicamente archivos Excel modernos .xlsx y .xlsm.']);
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) return const InventoryImportResult(products: [], errors: ['El archivo no parece ser un libro Excel moderno válido (.xlsx/.xlsm).']);
    try {
      final workbook = Excel.decodeBytes(bytes); if (workbook.tables.isEmpty) return const InventoryImportResult(products: [], errors: ['El archivo Excel no contiene ninguna hoja.']);
      final rows = workbook[workbook.tables.keys.first].rows; if (rows.isEmpty) return const InventoryImportResult(products: [], errors: ['La hoja de Excel está vacía.']);
      final headerMap = _buildHeaderMap(rows.first); if (!headerMap.containsKey('producto')) return const InventoryImportResult(products: [], errors: ['No se encontró la columna "Producto". Usa el archivo exportado por STELLAR POS como plantilla.']);
      final products = <Product>[]; final errors = <String>[];
      for (var index = 1; index < rows.length; index++) {
        final row = rows[index]; if (_rowIsEmpty(row)) continue; final excelRow = index + 1; final name = _read(row, headerMap, 'producto').trim(); if (name.isEmpty) { errors.add('Fila $excelRow: falta el nombre del producto.'); continue; }
        final cost = _readDouble(row, headerMap, 'precio de compra'); final price = _readDouble(row, headerMap, 'precio de venta'); final stock = _readInt(row, headerMap, 'stock'); final minStock = _readInt(row, headerMap, 'stock minimo'); final maxStock = _readInt(row, headerMap, 'stock maximo');
        if (cost < 0 || price < 0 || stock < 0 || minStock < 0 || maxStock < 0) { errors.add('Fila $excelRow: los valores numéricos no pueden ser negativos.'); continue; }
        final hasGroupPricing = _readBool(row, headerMap, 'venta por grupos'); final groupQuantity = _readInt(row, headerMap, 'unidades por grupo'); final groupPrice = _readDouble(row, headerMap, 'precio por grupo');
        if (hasGroupPricing && (groupQuantity <= 0 || groupPrice < 0)) { errors.add('Fila $excelRow: la configuración de venta por grupos no es válida.'); continue; }
        products.add(Product(id: _read(row, headerMap, 'id').trim(), name: name, unit: _read(row, headerMap, 'unidad').trim(), category: _read(row, headerMap, 'categoria').trim(), brand: _read(row, headerMap, 'marca').trim(), department: _read(row, headerMap, 'distribuidora').trim(), cost: cost, price: price, stock: stock, minStock: minStock, maxStock: maxStock, barcode: _read(row, headerMap, 'codigo de barras').trim(), hasGroupPricing: hasGroupPricing, groupQuantity: groupQuantity, groupPrice: groupPrice));
      }
      if (products.isEmpty && errors.isEmpty) errors.add('No se encontraron productos para importar.');
      return InventoryImportResult(products: products, errors: errors);
    } catch (_) { return const InventoryImportResult(products: [], errors: ['No se pudo leer el libro Excel. Verifica que sea un .xlsx o .xlsm válido y que contenga la estructura de inventario esperada.']); }
  }

  static Map<String, int> _buildHeaderMap(List<dynamic> row) { final map = <String, int>{}; for (var index = 0; index < row.length; index++) { final normalized = _normalizeHeader(_cellText(row[index])); if (normalized.isNotEmpty) map[normalized] = index; } return map; }
  static String _normalizeHeader(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u');
    const aliases = <String, String>{'nombre': 'producto', 'producto': 'producto', 'unidad': 'unidad', 'cantidad': 'unidad', 'cant.': 'unidad', 'cant': 'unidad', 'categoria': 'categoria', 'marca': 'marca', 'distribuidora': 'distribuidora', 'distribuidor': 'distribuidora', 'proveedor': 'distribuidora', 'costo unitario': 'precio de compra', 'costo': 'precio de compra', 'precio de compra': 'precio de compra', 'precio unitario': 'precio de venta', 'p. venta': 'precio de venta', 'precio venta': 'precio de venta', 'precio de venta': 'precio de venta', 'stock': 'stock', 'cant disponible': 'stock', 'cant. disponible': 'stock', 'stock minimo': 'stock minimo', 'stock mínimo': 'stock minimo', 'minimo': 'stock minimo', 'stock maximo': 'stock maximo', 'stock máximo': 'stock maximo', 'maximo': 'stock maximo', 'codigo de barras': 'codigo de barras', 'codigo': 'codigo de barras', 'barcode': 'codigo de barras', 'id': 'id', 'venta por grupos': 'venta por grupos', 'vender por grupos': 'venta por grupos', 'unidades por grupo': 'unidades por grupo', 'cantidad por grupo': 'unidades por grupo', 'precio por grupo': 'precio por grupo'};
    return aliases[normalized] ?? normalized;
  }
  static String _read(List<dynamic> row, Map<String, int> headers, String key) { final index = headers[_normalizeHeader(key)]; if (index == null || index >= row.length) return ''; return _cellText(row[index]); }
  static double _readDouble(List<dynamic> row, Map<String, int> headers, String key) => double.tryParse(_read(row, headers, key).replaceAll(',', '.')) ?? 0;
  static int _readInt(List<dynamic> row, Map<String, int> headers, String key, {int fallback = 0}) { final value = _read(row, headers, key).replaceAll(',', '.'); return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback; }
  static bool _readBool(List<dynamic> row, Map<String, int> headers, String key) { final value = _read(row, headers, key).trim().toLowerCase(); return value == 'true' || value == '1' || value == 'si' || value == 'sí' || value == 'yes'; }
  static String _cellText(dynamic cell) { if (cell == null) return ''; final value = cell.value; if (value == null) return ''; return switch (value) { TextCellValue(:final value) => value.toString(), IntCellValue(:final value) => value.toString(), DoubleCellValue(:final value) => value.toString(), BoolCellValue(:final value) => value.toString(), DateCellValue(:final year, :final month, :final day) => '$year-$month-$day', DateTimeCellValue(:final year, :final month, :final day, :final hour, :final minute, :final second, :final millisecond) => '$year-$month-$day $hour:$minute:$second.$millisecond', TimeCellValue(:final hour, :final minute, :final second, :final millisecond) => '$hour:$minute:$second.$millisecond', FormulaCellValue(:final formula) => formula.toString(), _ => value.toString() }; }
  static bool _rowIsEmpty(List<dynamic> row) => row.every((cell) => _cellText(cell).trim().isEmpty);
  static String _money(double value) => '\$${value.toStringAsFixed(2)}';
  static String _dateStamp() { final now = DateTime.now(); String two(int value) => value.toString().padLeft(2, '0'); return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}'; }
  static String _dateLabel() => '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}';
}
