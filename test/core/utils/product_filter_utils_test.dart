import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/utils/product_filter_utils.dart';

void main() {
  test('filters products by distributor', () {
    final products = [
      <String, dynamic>{
        'id': 'p1',
        'name': 'Coca Cola',
        'department': 'Coca Cola',
        'brand': 'Coca Cola',
        'category': 'Bebidas',
      },
      <String, dynamic>{
        'id': 'p2',
        'name': 'Pepsi',
        'department': 'PepsiCo',
        'brand': 'Pepsi',
        'category': 'Bebidas',
      },
      <String, dynamic>{
        'id': 'p3',
        'name': 'Agua',
        'department': 'Coca Cola',
        'brand': 'Cristal',
        'category': 'Bebidas',
      },
    ];

    final filtered = ProductFilterUtils.apply(
      products: products,
      searchQuery: '',
      selectedFilter: 'distributor:Coca Cola',
      tags: const ['Bebidas'],
      selectedTagIndex: 0,
    );

    expect(filtered.map((product) => product['id']), ['p1', 'p3']);
  });
}
