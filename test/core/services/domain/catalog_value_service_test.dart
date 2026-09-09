import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/domain/services/catalog_value_service.dart';

void main() {
  const service = CatalogValueService();

  test('normalizes names and compares case-insensitively', () {
    expect(service.normalizeName('  Coca Cola  '), 'Coca Cola');
    expect(service.containsIgnoreCase(['Coca Cola'], ' coca cola '), isTrue);
  });

  test('removes duplicate catalog values and sorts them', () {
    expect(
      service.uniqueSorted(['Banana', ' apple ', 'BANANA', 'Apple']),
      ['apple', 'Banana'],
    );
  });

  test('normalizes weekdays to unique values from 0 to 6', () {
    expect(
      service.normalizeWeekdays([7, 2, 0, 2, -1, 6]),
      [0, 2, 6],
    );
  });
}
