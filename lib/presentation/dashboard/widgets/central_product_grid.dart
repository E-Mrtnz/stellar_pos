import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/utils/product_filter_utils.dart';
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
    final filteredProducts = ProductFilterUtils.apply(
      products: products,
      searchQuery: searchQuery,
      selectedFilter: selectedFilter,
      tags: tags,
      selectedTagIndex: selectedTagIndex,
    );

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
