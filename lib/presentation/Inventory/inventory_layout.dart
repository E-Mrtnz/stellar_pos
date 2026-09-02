import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/utils/product_filter_utils.dart';
import 'package:stellar_pos/core/utils/product_utils.dart';
import 'package:stellar_pos/presentation/Inventory/widgets/create_client_dialog.dart';
import 'package:stellar_pos/presentation/Inventory/widgets/create_product_dialog.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/metric_card.dart';
import 'package:stellar_pos/presentation/inventory/widgets/create_catalog_dialog.dart';
import 'package:stellar_pos/presentation/widgets/product_filter_bar.dart';
import 'package:stellar_pos/presentation/widgets/product_search_bar.dart';

class InventoryLayout extends StatefulWidget {
  const InventoryLayout({super.key});

  @override
  State<InventoryLayout> createState() => _InventoryLayoutState();
}

class _InventoryLayoutState extends State<InventoryLayout> {
  int _selectedTagIndex = 0;
  String? _selectedFilter = 'all';
  String _searchQuery = '';

  List<String> get _tags => context.watch<CatalogProvider>().tags;

  List<Map<String, dynamic>> _filterProducts(
    List<Map<String, dynamic>> products,
  ) {
    return ProductFilterUtils.apply(
      products: products,
      searchQuery: _searchQuery,
      selectedFilter: _selectedFilter,
      tags: _tags,
      selectedTagIndex: _selectedTagIndex,
    );
  }

  Future<void> _createProduct() async {
    await CreateProductDialog.show(context);
  }

  Future<void> _createClient() async {
    await CreateClientDialog.show(context);
  }

  Future<void> _createCatalogItem() async {
    await CreateCatalogDialog.show(context);
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    await CreateProductDialog.show(context, product: product);
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().productMaps;
    final filteredProducts = _filterProducts(products);

    final totalInvestment = products.fold<double>(0, (total, product) {
      return total + ProductUtils.cost(product) * ProductUtils.stock(product);
    });

    final totalSales = products.fold<double>(0, (total, product) {
      return total + ProductUtils.price(product) * ProductUtils.stock(product);
    });

    final totalProfit = totalSales - totalInvestment;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopHeader(
                  totalInvestment,
                  totalSales,
                  totalProfit,
                  products.length,
                ),
                const SizedBox(height: 12),
                ProductFilterBar(
                  tags: _tags,
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (filter) {
                    setState(() => _selectedFilter = filter);
                  },
                  selectedTagIndex: _selectedTagIndex,
                  onTagSelected: (index) {
                    setState(() => _selectedTagIndex = index);
                  },
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildInventoryTable(filteredProducts)),
              ],
            ),
          ),
          _buildFloatingActions(),
        ],
      ),
    );
  }

  Widget _buildTopHeader(
    double totalInvestment,
    double totalSales,
    double totalProfit,
    int productCount,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ProductSearchBar(
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        const SizedBox(width: 12),
        MetricCard(
          amount: productCount.toString(),
          label: 'Productos',
          color: const Color(0xFFF59E0B),
          icon: Icons.inventory_2_outlined,
        ),
        const SizedBox(width: 8),
        MetricCard(
          amount: ProductUtils.money(totalInvestment),
          label: 'Inversión total',
          color: AppColors.dangerRed,
          icon: Icons.payment_outlined,
          iconRotation: 3.141592653589793,
          paymentArrow: true,
        ),
        const SizedBox(width: 8),
        MetricCard(
          amount: ProductUtils.money(totalSales),
          label: 'Ingreso estimado',
          color: AppColors.primary,
          icon: Icons.payment_outlined,
          paymentArrow: true,
        ),
        const SizedBox(width: 8),
        MetricCard(
          amount: ProductUtils.money(totalProfit),
          label: 'Ganancia estimada',
          color: AppColors.successGreen,
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }

  Widget _buildInventoryTable(List<Map<String, dynamic>> products) {
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
          Expanded(child: _buildInventoryList(products)),
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
          SizedBox(
            width: 45,
            child: Text('Editar', style: AppTextStyles.inventoryHeader),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList(List<Map<String, dynamic>> products) {
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
      itemBuilder: (context, index) => _buildInventoryRow(products[index]),
    );
  }

  Widget _buildInventoryRow(Map<String, dynamic> product) {
    final cost = ProductUtils.cost(product);
    final price = ProductUtils.price(product);
    final stock = ProductUtils.stock(product);
    final profit = ProductUtils.profit(product);
    final profitPercent =
        ProductUtils.profitPercentage(product).toStringAsFixed(0);
    final name = ProductUtils.cleanName(product);
    final imageData = ProductUtils.asString(product['imageData']);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _buildInventoryImage(imageData),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              name,
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
          SizedBox(
            width: 45,
            child: IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.primary,
              onPressed: () => _editProduct(product),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryImage(String imageData) {
    if (imageData.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(imageData),
            width: AppDimensions.inventoryImageSize,
            height: AppDimensions.inventoryImageSize,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }

    return Container(
      width: AppDimensions.inventoryImageSize,
      height: AppDimensions.inventoryImageSize,
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
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
            onPressed: _createCatalogItem,
          ),
          const SizedBox(height: 12),
          _buildCircularFab(
            heroTag: 'fab_clients',
            tooltip: AppStrings.createClientsTooltip,
            icon: Icons.person_add_alt_1_outlined,
            onPressed: _createClient,
          ),
          const SizedBox(height: 12),
          _buildCircularFab(
            heroTag: 'fab_products',
            tooltip: AppStrings.createProductsTooltip,
            icon: Icons.inventory_2_outlined,
            onPressed: _createProduct,
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
