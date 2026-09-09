import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:stellar_pos/core/data/import_export/inventory_import_mapper.dart';
import 'package:stellar_pos/core/models/product.dart';

class InventoryExcelImportResult {
  final List<Product> products;
  final List<String> errors;

  const InventoryExcelImportResult({
    required this.products,
    required this.errors,
  });
}

/// Owns Excel-specific input/output for inventory.
///
/// Row-to-domain conversion remains in [InventoryImportMapper], keeping file
/// format concerns separate from domain mapping and presentation.
class InventoryExcelService {
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

  static const Set<String> supportedExtensions =
      InventoryImportMapper.supportedExtensions;

  static Future<void> save(List<Product> products) async {
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
      final product = products[rowIndex];
      final values = <CellValue>[
        TextCellValue(product.id),
        TextCellValue(product.name),
        TextCellValue(product.unit),
        TextCellValue(product.category),
        TextCellValue(product.brand),
        TextCellValue(product.department),
        DoubleCellValue(product.cost),
        DoubleCellValue(product.price),
        IntCellValue(product.stock),
        IntCellValue(product.minStock),
        IntCellValue(product.maxStock),
        TextCellValue(product.barcode),
        TextCellValue(product.hasGroupPricing ? 'Sí' : 'No'),
        IntCellValue(product.groupQuantity),
        DoubleCellValue(product.groupPrice),
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

  static Future<InventoryExcelImportResult> parse(
    Uint8List bytes,
    String extension,
  ) async {
    final normalizedExtension = extension.toLowerCase().replaceFirst('.', '');
    if (!supportedExtensions.contains(normalizedExtension)) {
      return const InventoryExcelImportResult(
        products: [],
        errors: [
          'Formato no compatible. STELLAR POS acepta únicamente archivos Excel modernos .xlsx y .xlsm.',
        ],
      );
    }
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
      return const InventoryExcelImportResult(
        products: [],
        errors: [
          'El archivo no parece ser un libro Excel moderno válido (.xlsx/.xlsm).',
        ],
      );
    }

    try {
      final workbook = Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) {
        return const InventoryExcelImportResult(
          products: [],
          errors: ['El archivo Excel no contiene ninguna hoja.'],
        );
      }

      final rows = workbook[workbook.tables.keys.first].rows;
      final result = InventoryImportMapper.mapRows(rows);
      return InventoryExcelImportResult(
        products: result.products,
        errors: result.errors,
      );
    } catch (_) {
      return const InventoryExcelImportResult(
        products: [],
        errors: [
          'No se pudo leer el libro Excel. Verifica que sea un .xlsx o .xlsm válido y que contenga la estructura de inventario esperada.',
        ],
      );
    }
  }

  static String _dateStamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  }
}
