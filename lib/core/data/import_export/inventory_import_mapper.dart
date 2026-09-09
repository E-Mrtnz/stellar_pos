import 'package:excel/excel.dart';
import 'package:stellar_pos/core/models/product.dart';

/// Converts worksheet rows into domain products without handling files or UI.
class InventoryImportMapper {
  const InventoryImportMapper._();

  static const Set<String> supportedExtensions = {'xlsx', 'xlsm'};

  static InventoryImportMappingResult mapRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return const InventoryImportMappingResult(
        products: [],
        errors: ['La hoja de Excel está vacía.'],
      );
    }

    final headerMap = _buildHeaderMap(rows.first);
    if (!headerMap.containsKey('producto')) {
      return const InventoryImportMappingResult(
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
      final minStock = _readInt(row, headerMap, 'stock minimo');
      final maxStock = _readInt(row, headerMap, 'stock maximo');

      if (cost < 0 || price < 0 || stock < 0 || minStock < 0 || maxStock < 0) {
        errors.add(
          'Fila $excelRow: los valores numéricos no pueden ser negativos.',
        );
        continue;
      }

      final hasGroupPricing = _readBool(row, headerMap, 'venta por grupos');
      final groupQuantity = _readInt(row, headerMap, 'unidades por grupo');
      final groupPrice = _readDouble(row, headerMap, 'precio por grupo');

      if (hasGroupPricing && (groupQuantity <= 0 || groupPrice < 0)) {
        errors.add(
          'Fila $excelRow: la configuración de venta por grupos no es válida.',
        );
        continue;
      }

      products.add(
        Product(
          id: _read(row, headerMap, 'id').trim(),
          name: name,
          unit: _read(row, headerMap, 'unidad').trim(),
          category: _read(row, headerMap, 'categoria').trim(),
          brand: _read(row, headerMap, 'marca').trim(),
          department: _read(row, headerMap, 'distribuidora').trim(),
          cost: cost,
          price: price,
          stock: stock,
          minStock: minStock,
          maxStock: maxStock,
          barcode: _read(row, headerMap, 'codigo de barras').trim(),
          hasGroupPricing: hasGroupPricing,
          groupQuantity: groupQuantity,
          groupPrice: groupPrice,
        ),
      );
    }

    if (products.isEmpty && errors.isEmpty) {
      errors.add('No se encontraron productos para importar.');
    }

    return InventoryImportMappingResult(products: products, errors: errors);
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
      'unidad': 'unidad',
      'cantidad': 'unidad',
      'cant.': 'unidad',
      'cant': 'unidad',
      'categoria': 'categoria',
      'marca': 'marca',
      'distribuidora': 'distribuidora',
      'distribuidor': 'distribuidora',
      'proveedor': 'distribuidora',
      'costo unitario': 'precio de compra',
      'costo': 'precio de compra',
      'precio de compra': 'precio de compra',
      'precio unitario': 'precio de venta',
      'p. venta': 'precio de venta',
      'precio venta': 'precio de venta',
      'precio de venta': 'precio de venta',
      'stock': 'stock',
      'cant disponible': 'stock',
      'cant. disponible': 'stock',
      'stock minimo': 'stock minimo',
      'stock mínimo': 'stock minimo',
      'minimo': 'stock minimo',
      'stock maximo': 'stock maximo',
      'stock máximo': 'stock maximo',
      'maximo': 'stock maximo',
      'codigo de barras': 'codigo de barras',
      'codigo': 'codigo de barras',
      'barcode': 'codigo de barras',
      'id': 'id',
      'venta por grupos': 'venta por grupos',
      'vender por grupos': 'venta por grupos',
      'unidades por grupo': 'unidades por grupo',
      'cantidad por grupo': 'unidades por grupo',
      'precio por grupo': 'precio por grupo',
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
  ) => double.tryParse(_read(row, headers, key).replaceAll(',', '.')) ?? 0;

  static int _readInt(
    List<dynamic> row,
    Map<String, int> headers,
    String key, {
    int fallback = 0,
  }) {
    final value = _read(row, headers, key).replaceAll(',', '.');
    return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
  }

  static bool _readBool(
    List<dynamic> row,
    Map<String, int> headers,
    String key,
  ) {
    final value = _read(row, headers, key).trim().toLowerCase();
    return value == 'true' ||
        value == '1' ||
        value == 'si' ||
        value == 'sí' ||
        value == 'yes';
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
      TimeCellValue(:final hour, :final minute, :final second,
        :final millisecond) => '$hour:$minute:$second.$millisecond',
      FormulaCellValue(:final formula) => formula.toString(),
      _ => value.toString(),
    };
  }

  static bool _rowIsEmpty(List<dynamic> row) =>
      row.every((cell) => _cellText(cell).trim().isEmpty);
}

class InventoryImportMappingResult {
  final List<Product> products;
  final List<String> errors;

  const InventoryImportMappingResult({
    required this.products,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}