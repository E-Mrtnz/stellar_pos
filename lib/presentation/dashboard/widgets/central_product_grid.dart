import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/product_card.dart';
import 'package:stellar_pos/presentation/widgets/category_selector.dart';

class CentralProductGrid extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Map<String, int> cartQuantities;

  final List<String> categories;
  final int selectedCategoryIndex;

  final ValueChanged<int> onCategorySelected;

  final ValueChanged<String> onAddToCart;
  final ValueChanged<String> onRemoveFromCart;

  final TextEditingController? searchController;

  const CentralProductGrid({
    super.key,
    required this.products,
    required this.cartQuantities,
    required this.categories,
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filteredProducts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(
          AppDimensions.largeCardRadius,
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(),

          const SizedBox(height: 12),

          CategorySelector(
            categories: categories,
            selectedCategoryIndex: selectedCategoryIndex,
            onCategorySelected: onCategorySelected,
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
    if (selectedCategoryIndex == 0) {
      return products;
    }

    if (selectedCategoryIndex >= categories.length) {
      return products;
    }

    final category = categories[selectedCategoryIndex];

    return products
        .where((product) => product['category'] == category)
        .toList();
  }

  Widget _buildSearchField() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: AppStrings.searchPlaceholder,
        hintStyle: AppTextStyles.searchHint,
        prefixIcon: const Icon(
          Icons.search,
          color: AppColors.textSecondary,
        ),
        fillColor: AppColors.inputBackground,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppDimensions.searchFieldRadius,
          ),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppDimensions.searchFieldRadius,
          ),
          borderSide: const BorderSide(color: AppColors.border),
        ),
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
          onAdd: () {
            onAddToCart(productId);
          },
          onRemove: () {
            onRemoveFromCart(productId);
          },
        );
      },
    );
  }
}
