import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/data/import_export/inventory_import_mapper.dart';

void main() {
  dynamic textCell(String value) => TextCellValue(value);
  dynamic numberCell(double value) => DoubleCellValue(value);
  dynamic integerCell(int value) => IntCellValue(value);

  test('maps exported inventory columns into products', () {
    final rows = <List<dynamic>>[
      [
        textCell('ID'),
        textCell('Producto'),
        textCell('Cant.'),
        textCell('Categoría'),
        textCell('Marca'),
        textCell('Distribuidora'),
        textCell('Precio de compra'),
        textCell('Precio de venta'),
        textCell('Stock'),
        textCell('Stock mínimo'),
        textCell('Stock máximo'),
        textCell('Código de barras'),
        textCell('Venta por grupos'),
        textCell('Unidades por grupo'),
        textCell('Precio por grupo'),
      ],
      [
        textCell('p1'),
        textCell('Coca-Cola'),
        textCell('354 ml'),
        textCell('Bebidas'),
        textCell('Coca-Cola'),
        textCell('Distribuidora A'),
        numberCell(0.55),
        numberCell(0.75),
        integerCell(12),
        integerCell(3),
        integerCell(30),
        textCell('750123'),
        textCell('Sí'),
        integerCell(3),
        numberCell(2.00),
      ],
    ];

    final result = InventoryImportMapper.mapRows(rows);

    expect(result.errors, isEmpty);
    expect(result.products, hasLength(1));
    final product = result.products.single;
    expect(product.id, 'p1');
    expect(product.unit, '354 ml');
    expect(product.stock, 12);
    expect(product.hasGroupPricing, isTrue);
    expect(product.groupQuantity, 3);
    expect(product.groupPrice, 2.00);
  });

  test('reports missing product names instead of creating invalid rows', () {
    final rows = <List<dynamic>>[
      [textCell('Producto'), textCell('Stock')],
      [textCell(''), integerCell(5)],
    ];

    final result = InventoryImportMapper.mapRows(rows);

    expect(result.products, isEmpty);
    expect(result.errors, contains('Fila 2: falta el nombre del producto.'));
  });

  test('accepts legacy aliases for inventory columns', () {
    final rows = <List<dynamic>>[
      [textCell('Nombre'), textCell('Cantidad'), textCell('Costo'), textCell('Precio venta')],
      [textCell('Arroz'), textCell('1 kg'), numberCell(0.80), numberCell(1.10)],
    ];

    final result = InventoryImportMapper.mapRows(rows);

    expect(result.errors, isEmpty);
    expect(result.products.single.name, 'Arroz');
    expect(result.products.single.unit, '1 kg');
    expect(result.products.single.cost, 0.80);
    expect(result.products.single.price, 1.10);
  });
}
