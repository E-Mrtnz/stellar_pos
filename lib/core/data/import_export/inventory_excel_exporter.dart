import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:stellar_pos/core/models/product.dart';

/// Generates and saves the inventory workbook without owning import logic.
class InventoryExcelExporter {
  const InventoryExcelExporter._();

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

  static String _dateStamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  }
}
