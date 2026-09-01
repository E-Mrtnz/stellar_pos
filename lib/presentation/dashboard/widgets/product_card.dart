import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/utils/product_utils.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int quantityInCart;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const ProductCard({
    super.key,
    required this.product,
    required this.quantityInCart,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasItemsInCart = quantityInCart > 0;

    final int stock = ProductUtils.stock(product);

    final int minStock = ProductUtils.minStock(product);

    final Color stockColor = _getStockColor(
      stock: stock,
      minStock: minStock,
    );

    return Material(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(
        AppDimensions.largeCardRadius,
      ),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(
          AppDimensions.largeCardRadius,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              AppDimensions.largeCardRadius,
            ),
            border: Border.all(
              color: hasItemsInCart
                  ? AppColors.primary
                  : AppColors.border,
              width: hasItemsInCart ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildProductImage()),

                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: _buildProductInfo(
                      stock: stock,
                      stockColor: stockColor,
                    ),
                  ),
                ],
              ),

              if (hasItemsInCart) _buildDeleteButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    return Container(
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
          size: AppDimensions.productImageSize,
        ),
      ),
    );
  }

  Widget _buildProductInfo({
    required int stock,
    required Color stockColor,
  }) {
    final name = ProductUtils.cleanName(product);

    final unit = ProductUtils.unit(product);

    final department = ProductUtils.department(product);

    final price = ProductUtils.price(product);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.productName,
        ),

        const SizedBox(height: 2),

        Text(
          '$unit | $department',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.productMetadata,
        ),

        const SizedBox(height: 7),

        _buildStockBadge(stock: stock, color: stockColor),

        const SizedBox(height: 7),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ProductUtils.money(price),
              style: AppTextStyles.productPrice,
            ),

            _buildCartCounter(),
          ],
        ),
      ],
    );
  }

  Widget _buildStockBadge({required int stock, required Color color}) {
    return Container(
      height: AppDimensions.stockBadgeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: color,
            size: AppSizes.iconSmall,
          ),
          const SizedBox(width: 5),
          Text(
            '$stock',
            style: TextStyle(
              color: color,
              fontSize: AppSizes.textMedium,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartCounter() {
    final bool hasItemsInCart = quantityInCart > 0;

    return Container(
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
                  fontSize: AppSizes.textMedium,
                  fontWeight: FontWeight.bold,
                ),
              )
            : const Icon(
                Icons.add,
                color: AppColors.textSecondary,
                size: AppSizes.iconSmall,
              ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Positioned(
      top: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onRemove,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(10),
          ),
          child: Container(
            width: 32,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.dangerRed.withAlpha(20),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(10),
              ),
              border: Border.all(
                color: AppColors.dangerRed.withAlpha(60),
              ),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: AppColors.dangerRed,
              size: AppSizes.iconMedium,
            ),
          ),
        ),
      ),
    );
  }

  Color _getStockColor({required int stock, required int minStock}) {
    if (stock <= minStock) {
      return AppColors.dangerRed;
    }

    if (stock <= minStock * AppInventory.warningMultiplier) {
      return AppColors.warningOrange;
    }

    return AppColors.successGreen;
  }
}
