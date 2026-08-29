import 'package:flutter/material.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
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
    final filteredProducts = products.where((product) {
      if (selectedCategoryIndex == 0) return true;
      final categoryName = categories[selectedCategoryIndex];
      return product['category'] == categoryName;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
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
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),

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
                ? const Center(
                    child: Text(
                      'No se encontraron productos',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : GridView.builder(
                    itemCount: filteredProducts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.82,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final productId = product['id'].toString();
                      final quantityInCart =
                          cartQuantities[productId] ?? 0;

                      return _buildProductCard(
                        product: product,
                        quantityInCart: quantityInCart,
                        onTap: () => onAddToCart(productId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required Map<String, dynamic> product,
    required int quantityInCart,
    required VoidCallback onTap,
  }) {
    final bool hasItemsInCart = quantityInCart > 0;

    return Material(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasItemsInCart
                  ? AppColors.primary
                  : AppColors.border,
              width: hasItemsInCart ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Área superior de la imagen ocupando los bordes top, left y right
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.textMuted,
                      size: 36,
                    ),
                  ),
                ),
              ),

              // Sección inferior con padding reservado para la información
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Stock: ${product['stock']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${(product['price'] as double).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primary,
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: hasItemsInCart
                                ? AppColors.primary
                                : AppColors.border.withAlpha(120),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: hasItemsInCart
                                ? Text(
                                    '$quantityInCart',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add,
                                    color: AppColors.textSecondary,
                                    size: 14,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
