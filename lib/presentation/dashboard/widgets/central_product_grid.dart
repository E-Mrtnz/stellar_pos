import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/utils/product_filter_utils.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/electronic_balance_sale_dialog.dart';
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
  final List<ElectronicBalanceCartItem> electronicBalanceSelection;
  final VoidCallback? onElectronicBalanceTap;
  final VoidCallback? onElectronicBalanceManage;
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
    this.electronicBalanceSelection = const [],
    this.onElectronicBalanceTap,
    this.onElectronicBalanceManage,
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
          ProductSearchBar(onChanged: onSearchChanged ?? (_) {}),
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
            child: filteredProducts.isEmpty && onElectronicBalanceTap == null
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
      itemCount: products.length + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: AppDimensions.productCardAspectRatio,
        crossAxisSpacing: AppDimensions.productGridSpacing,
        mainAxisSpacing: AppDimensions.productGridSpacing,
      ),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _ElectronicBalanceCard(
            selection: electronicBalanceSelection,
            onTap: onElectronicBalanceTap,
            onManage: onElectronicBalanceManage,
          );
        }

        final product = products[index - 1];
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

class _ElectronicBalanceCard extends StatelessWidget {
  final List<ElectronicBalanceCartItem> selection;
  final VoidCallback? onTap;
  final VoidCallback? onManage;

  const _ElectronicBalanceCard({
    required this.selection,
    required this.onTap,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final quantity = selection.fold<int>(0, (sum, item) => sum + item.quantity);
    final total = selection.fold<double>(
      0,
      (sum, item) => sum + item.amount * item.quantity,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selection.isEmpty
                ? AppColors.primary.withAlpha(10)
                : AppColors.primary.withAlpha(18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selection.isEmpty
                  ? AppColors.primary.withAlpha(70)
                  : AppColors.primary,
              width: selection.isEmpty ? 1 : 1.4,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.phone_android_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  if (onManage != null)
                    IconButton(
                      tooltip: 'Administrar compañías y recargas',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: onManage,
                      icon: const Icon(
                        Icons.settings_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              const Text(
                'Venta de saldo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selection.isEmpty
                    ? 'Recargas móviles'
                    : '$quantity recarga${quantity == 1 ? '' : 's'} · \$${total.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selection.isEmpty
                          ? 'Tocar para seleccionar'
                          : 'Tocar para editar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
