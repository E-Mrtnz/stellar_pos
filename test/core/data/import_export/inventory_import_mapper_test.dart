import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/data/import_export/inventory_import_mapper.dart';

void main() {
  Cell _text(String value) => TextCellValue(value);
  Cell _number(double value) => DoubleCellValue(value);
  Cell _integer(int value) => IntCellValue(value);

  test('maps exported inventory columns into products', () {
    final rows = <List<dynamic>>[
      [
        _text('ID'),
        _text('Producto'),
        _text('Cant.'),
        _text('Categoría'),
        _text('Marca'),
        _text('Distribuidora'),
        _text('Precio de compra'),
        _text('Precio de venta'),
        _text('Stock'),
        _text('Stock mínimo'),
        _text('Stock máximo'),
        _text('Código de barras'),
        _text('Venta por grupos'),
        _text('Unidades por grupo'),
        _text('Precio por grupo'),
      ],
      [
        _text('p1'),
        _text('Coca-Cola'),
        _text('354 ml'),
        _text('Bebidas'),
        _text('Coca-Cola'),
        _text('Distribuidora A'),
        _number(0.55),
        _number(0.75),
        _integer(12),
        _integer(3),
        _integer(30),
        _text('750123'),
        _text('Sí'),
        _integer(3),
        _number(2.00),
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
      [_text('Producto'), _text('Stock')],
      [_text(''), _integer(5)],
    ];

    final result = InventoryImportMapper.mapRows(rows);

    expect(result.products, isEmpty);
    expect(result.errors, contains('Fila 2: falta el nombre del producto.'));
  });

  test('accepts legacy aliases for inventory columns', () {
    final rows = <List<dynamic>>[
      [_text('Nombre'), _text('Cantidad'), _text('Costo'), _text('Precio venta')],
      [_text('Arroz'), _text('1 kg'), _number(0.80), _number(1.10)],
    ];

    final result = InventoryImportMapper.mapRows(rows);

    expect(result.errors, isEmpty);
    expect(result.products.single.name, 'Arroz');
    expect(result.products.single.unit, '1 kg');
    expect(result.products.single.cost, 0.80);
    expect(result.products.single.price, 1.10);
  });
}