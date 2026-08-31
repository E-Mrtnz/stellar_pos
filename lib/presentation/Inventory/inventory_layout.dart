import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/constants/app_data.dart';
import 'package:stellar_pos/core/utils/product_utils.dart';
import 'package:stellar_pos/presentation/Inventory/widgets/create_product_dialog.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/metric_card.dart';
import 'package:stellar_pos/presentation/widgets/category_selector.dart';

class InventoryLayout extends StatefulWidget {
  const InventoryLayout({super.key});

  @override
  State<InventoryLayout> createState() => _InventoryLayoutState();
}

class _InventoryLayoutState extends State<InventoryLayout> {
  int _selectedCategoryIndex = 0;

  List<Map<String, dynamic>> get _products => AppData.products;

  List<String> get _categories => AppCategories.all;

  List<Map<String, dynamic>> get _filteredProducts {
    if (_selectedCategoryIndex == 0) {
      return _products;
    }

    final category = _categories[_selectedCategoryIndex];

    return _products
        .where((product) => product['category'] == category)
        .toList();
  }

  double get _totalInvestment {
    return _products.fold(
      0,
      (total, product) =>
          total +
          ProductUtils.cost(product) * ProductUtils.stock(product),
    );
  }

  double get _totalSales {
    return _products.fold(
      0,
      (total, product) =>
          total +
          ProductUtils.price(product) * ProductUtils.stock(product),
    );
  }

  double get _totalProfit {
    return _totalSales - _totalInvestment;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopHeader(),

                const SizedBox(height: 12),

                CategorySelector(
                  categories: _categories,
                  selectedCategoryIndex: _selectedCategoryIndex,
                  onCategorySelected: (index) {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                  },
                ),

                const SizedBox(height: 12),

                Expanded(child: _buildInventoryTable()),
              ],
            ),
          ),

          _buildFloatingActions(),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              hintText: AppStrings.searchPlaceholder,
              hintStyle: AppTextStyles.searchHint,
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
              ),
              fillColor: AppColors.cardBackground,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
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
          ),
        ),

        const SizedBox(width: 12),

        MetricCard(
          amount: ProductUtils.money(_totalInvestment),
          label: AppStrings.totalInvestment,
          color: AppColors.textPrimary,
        ),

        const SizedBox(width: 8),

        MetricCard(
          amount: ProductUtils.money(_totalSales),
          label: AppStrings.totalSales,
          color: AppColors.primary,
        ),

        const SizedBox(width: 8),

        MetricCard(
          amount: ProductUtils.money(_totalProfit),
          label: AppStrings.totalProfit,
          color: AppColors.successGreen,
        ),
      ],
    );
  }

  Widget _buildInventoryTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildTableHeader(),

          const Divider(height: 1, color: AppColors.border),

          Expanded(child: _buildInventoryList()),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 40),
          SizedBox(width: 12),

          Expanded(
            flex: 3,
            child: Text(
              AppStrings.inventoryProductHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              AppStrings.inventoryCostHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              AppStrings.inventorySalePriceHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              AppStrings.inventoryStockHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              AppStrings.inventoryProfitHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),

          Expanded(
            flex: 1,
            child: Text(
              AppStrings.inventoryMarginHeader,
              style: AppTextStyles.inventoryHeader,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList() {
    final products = _filteredProducts;

    if (products.isEmpty) {
      return const Center(
        child: Text(
          AppStrings.inventoryEmptyMessage,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: products.length,
      separatorBuilder: (_, __) =>
          const Divider(color: AppColors.chipBackground),
      itemBuilder: (context, index) {
        return _buildInventoryRow(products[index]);
      },
    );
  }

  Widget _buildInventoryRow(Map<String, dynamic> product) {
    final cost = ProductUtils.cost(product);

    final price = ProductUtils.price(product);

    final stock = ProductUtils.stock(product);

    final profit = ProductUtils.profit(product);

    final profitPercent = ProductUtils.profitPercentage(
      product,
    ).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: AppDimensions.inventoryImageSize,
            height: AppDimensions.inventoryImageSize,
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.image_outlined,
              color: AppColors.textMuted,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 3,
            child: Text(
              ProductUtils.cleanName(product),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              ProductUtils.money(cost),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              ProductUtils.money(price),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              '$stock',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              ProductUtils.money(profit),
              style: const TextStyle(
                color: AppColors.successGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            flex: 1,
            child: Text(
              '$profitPercent%',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Positioned(
      right: 20,
      bottom: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCircularFab(
            heroTag: 'fab_tags',
            tooltip: AppStrings.createTagsTooltip,
            icon: Icons.label_outlined,
            onPressed: () {},
          ),

          const SizedBox(height: 12),

          _buildCircularFab(
            heroTag: 'fab_clients',
            tooltip: AppStrings.createClientsTooltip,
            icon: Icons.person_add_alt_1_outlined,
            onPressed: () {},
          ),

          const SizedBox(height: 12),

          _buildCircularFab(
            heroTag: 'fab_products',
            tooltip: AppStrings.createProductsTooltip,
            icon: Icons.inventory_2_outlined,
            onPressed: () {
              CreateProductDialog.show(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCircularFab({
    required String heroTag,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      tooltip: tooltip,
      onPressed: onPressed,
      elevation: AppDimensions.inventoryFabElevation,
      shape: const CircleBorder(),
      backgroundColor: AppColors.primary,
      child: Icon(icon, color: Colors.white, size: AppSizes.iconLarge),
    );
  }
}
