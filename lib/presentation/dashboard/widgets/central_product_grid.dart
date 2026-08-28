import 'package:flutter/material.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';

class CentralProductGrid extends StatelessWidget {
  final List<String> categories;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategorySelected;
  final List<Map<String, dynamic>> products;
  final Map<String, int> cartQuantities;
  final ValueChanged<String> onAddToCart;
  final ValueChanged<String> onRemoveFromCart;

  const CentralProductGrid({
    super.key,
    required this.categories,
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
    required this.products,
    required this.cartQuantities,
    required this.onAddToCart,
    required this.onRemoveFromCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de Búsqueda
          SizedBox(
            height: 40,
            child: TextField(
              decoration: InputDecoration(
                hintText: AppStrings.searchPlaceholder,
                hintStyle: AppTextStyles.searchHint,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.inputBackground,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),

          // Chips de Categorías
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final isSelected = selectedCategoryIndex == index;
                return ChoiceChip(
                  label: Text(categories[index]),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.chipBackground,
                  labelStyle: AppTextStyles.chipText.copyWith(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: BorderSide.none,
                  onSelected: (_) => onCategorySelected(index),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Grid de Productos
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductCard(product);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final String productId = product['id'] as String;
    final int countInCart = cartQuantities[productId] ?? 0;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Tarjeta completa interactiva
          InkWell(
            onTap: () => onAddToCart(productId),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: countInCart > 0
                      ? AppColors.primary.withAlpha(120)
                      : AppColors.border,
                  width: countInCart > 0 ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 38,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Stock: ${product['stock']}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\$${(product['price'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: countInCart > 0
                                    ? AppColors.primary
                                    : AppColors.inputBackground,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: countInCart > 0
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                countInCart > 0 ? 'X$countInCart' : '+',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: countInCart > 0
                                      ? Colors.white
                                      : AppColors.textSecondary,
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

          // Botón Eliminar en la esquina superior derecha
          if (countInCart > 0)
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: () => onRemoveFromCart(productId),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(15),
                  bottomLeft: Radius.circular(10),
                ),
                child: Container(
                  width: 34,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(244, 67, 54, 0.12),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(15),
                      bottomLeft: Radius.circular(10),
                    ),
                    border: Border.all(
                      color: const Color.fromRGBO(244, 67, 54, 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
