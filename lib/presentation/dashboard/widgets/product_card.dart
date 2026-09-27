import 'package:flutter/material.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/presentation/widgets/product_image.dart';
import 'package:stellar_pos/core/utils/product_utils.dart';

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int quantityInCart;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final bool preparedSelected;
  final ValueChanged<bool> onPreparedChanged;

  const ProductCard({
    super.key,
    required this.product,
    required this.quantityInCart,
    required this.onAdd,
    required this.onRemove,
    this.preparedSelected = false,
    required this.onPreparedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasItemsInCart = quantityInCart > 0;
    final stock = ProductUtils.stock(product);
    final minStock = ProductUtils.minStock(product);
    final stockColor = _getStockColor(stock: stock, minStock: minStock);

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
            border: Border.all(
              color: hasItemsInCart ? AppColors.primary : AppColors.border,
              width: hasItemsInCart ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
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
    final imageData = product['imageData']?.toString().trim() ?? '';
    final productId = product['id']?.toString() ?? '';

    if (imageData.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: AppColors.cardBackground),
        child: const Icon(
          Icons.inventory_2_outlined,
          color: AppColors.textMuted,
        ),
      );
    }

    return ProductImage(
      productId: productId,
      imageData: imageData,
      width: double.infinity,
      fit: BoxFit.contain,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(15),
        topRight: Radius.circular(15),
      ),
      placeholderIcon: Icons.inventory_2_outlined,
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
              border: Border.all(color: AppColors.dangerRed.withAlpha(50)),
            ),
            child: const Icon(
              Icons.close,
              color: AppColors.dangerRed,
              size: 17,
            ),
          ),
        ),
      ),
    );
  }

  Color _getStockColor({required int stock, required int minStock}) {
    if (stock <= minStock) return AppColors.dangerRed;
    if (stock <= minStock * AppInventory.warningMultiplier) {
      return AppColors.warningOrange;
    }
    return AppColors.successGreen;
  }
}