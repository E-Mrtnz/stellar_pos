import 'package:stellar_pos/core/utils/product_utils.dart';

class ProductFilterUtils {
  const ProductFilterUtils._();

  static List<Map<String, dynamic>> apply({
    required List<Map<String, dynamic>> products,
    required String searchQuery,
    required String? selectedFilter,
    required List<String> tags,
    required int selectedTagIndex,
  }) {
    var filtered = products;

    filtered = _filterBySearch(filtered, searchQuery);
    filtered = _filterByStatus(filtered, selectedFilter);

    if (selectedTagIndex == 0 || selectedTagIndex > tags.length) {
      return filtered;
    }

    final selectedTag = tags[selectedTagIndex - 1];

    return filtered
        .where((product) =>
            ProductUtils.asString(product['category']) == selectedTag)
        .toList();
  }

  static List<Map<String, dynamic>> _filterBySearch(
    List<Map<String, dynamic>> products,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return products;
    }

    final terms = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    return products.where((product) {
      final name = ProductUtils.asString(product['name']).toLowerCase();
      final barcode = ProductUtils.asString(product['barcode']).toLowerCase();

      return terms.any(
        (term) => name.contains(term) || barcode.contains(term),
      );
    }).toList();
  }

  static List<Map<String, dynamic>> _filterByStatus(
    List<Map<String, dynamic>> products,
    String? selectedFilter,
  ) {
    switch (selectedFilter) {
      case 'missing_cost':
        return products.where(_hasMissingCost).toList();
      case 'missing_barcode':
        return products.where(_hasMissingBarcode).toList();
      case 'missing_tag':
        return products.where(_hasMissingTag).toList();
      case 'missing_department':
        return products.where(_hasMissingDepartment).toList();
      default:
        return products;
    }
  }

  static bool _hasMissingCost(Map<String, dynamic> product) {
    final value = product['cost'];

    if (value == null) {
      return true;
    }

    if (value is num) {
      return value <= 0;
    }

    final text = value.toString().trim();
    final parsed = double.tryParse(text.replaceAll(',', '.')) ?? 0;

    return text.isEmpty || parsed <= 0;
  }

  static bool _hasMissingBarcode(Map<String, dynamic> product) {
    return ProductUtils.asString(product['barcode']).isEmpty;
  }

  static bool _hasMissingTag(Map<String, dynamic> product) {
    return ProductUtils.asString(product['category']).isEmpty;
  }

  static bool _hasMissingDepartment(Map<String, dynamic> product) {
    return ProductUtils.asString(product['department']).isEmpty;
  }
}
