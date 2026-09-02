import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/product_card.dart';
import 'package:stellar_pos/presentation/widgets/product_filter_bar.dart';
import 'package:stellar_pos/presentation/widgets/product_search_bar.dart';

class CentralProductGrid extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Map<String, int> cartQuantities;
  final List<String> tags;
  final int selectedTagIndex;
  final ValueChanged<int> onTagSelected;
  final String? selectedFilter;
  final ValueChanged<String?> onFilterChanged;
  final ValueChanged<String> onAddToCart;
  final ValueChanged<String> onRemoveFromCart;
  final ValueChanged<String>? onSearchChanged;
  final String searchQuery;

  const CentralProductGrid({
    super.key,
    required this.products,
    required this.cartQuantities,
    required this.tags,
    required this.selectedTagIndex,
    required this.onTagSelected,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    this.onSearchChanged,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filteredProducts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductSearchBar(
            onChanged: onSearchChanged ?? (_) {},
          ),
          const SizedBox(height: 12),
          ProductFilterBar(
            tags: tags,
            selectedFilter: selectedFilter,
            onFilterChanged: onFilterChanged,
            selectedTagIndex: selectedTagIndex,
            onTagSelected: onTagSelected,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Expanded(
            child: filteredProducts.isEmpty
                ? _buildEmptyState()
                : _buildProductGrid(filteredProducts),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredProducts {
    var filtered = products;

    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((product) {
        final name = _value(product['name']).toLowerCase();
        final barcode = _value(product['barcode']).toLowerCase();
        return name.startsWith(query) || barcode.startsWith(query);
      }).toList();
    }

    switch (selectedFilter) {
      case 'missing_cost':
        filtered = filtered.where(_hasMissingCost).toList();
        break;
      case 'missing_barcode':
        filtered = filtered.where(_hasMissingBarcode).toList();
        break;
      case 'missing_tag':
        filtered = filtered.where(_hasMissingTag).toList();
        break;
      case 'missing_department':
        filtered = filtered.where(_hasMissingDepartment).toList();
        break;
    }

    if (selectedTagIndex == 0 || selectedTagIndex > tags.length) {
      return filtered;
    }

    final tag = tags[selectedTagIndex - 1];
    return filtered
        .where((product) => _value(product['category']) == tag)
        .toList();
  }

  bool _hasMissingCost(Map<String, dynamic> product) {
    final value = product['cost'];
    if (value == null) return true;
    if (value is num) return value <= 0;
    final text = value.toString().trim();
    return text.isEmpty ||
        (double.tryParse(text.replaceAll(',', '.')) ?? 0) <= 0;
  }

  bool _hasMissingBarcode(Map<String, dynamic> product) {
    return _value(product['barcode']).isEmpty;
  }

  bool _hasMissingTag(Map<String, dynamic> product) {
    return _value(product['category']).isEmpty;
  }

  bool _hasMissingDepartment(Map<String, dynamic> product) {
    return _value(product['department']).isEmpty;
  }

  String _value(dynamic value) => value?.toString().trim() ?? '';

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'No se encontraron productos',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildProductGrid(List<Map<String, dynamic>> products) {
    return GridView.builder(
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: AppDimensions.productCardAspectRatio,
        crossAxisSpacing: AppDimensions.productGridSpacing,
        mainAxisSpacing: AppDimensions.productGridSpacing,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        final productId = product['id'].toString();

        return ProductCard(
          product: product,
          quantityInCart: cartQuantities[productId] ?? 0,
          onAdd: () => onAddToCart(productId),
          onRemove: () => onRemoveFromCart(productId),
        );
      },
    );
  }
}
