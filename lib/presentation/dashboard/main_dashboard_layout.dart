import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';

import 'package:stellar_pos/presentation/Inventory/inventory_layout.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/central_product_grid.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sales_summary_panel.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sidebar_drawer.dart';

class MainDashboardLayout extends StatefulWidget {
  const MainDashboardLayout({super.key});

  @override
  State<MainDashboardLayout> createState() =>
      _MainDashboardLayoutState();
}

class _MainDashboardLayoutState extends State<MainDashboardLayout> {
  int _selectedNavIndex = AppNavigation.home;
  int _selectedCategoryIndex = 0;

  bool _isSidebarExpanded = true;

  final Map<String, int> _cartQuantities = {};

  int _selectedPaymentMethod = AppPaymentMethods.cash;

  String? _selectedDebtor;

  final TextEditingController _discountAmountController =
      TextEditingController();

  final TextEditingController _discountPercentController =
      TextEditingController();

  final TextEditingController _cashReceivedController =
      TextEditingController();

  List<String> get _categories => AppCategories.all;

  List<String> get _debtors => const [];

  @override
  void dispose() {
    _discountAmountController.dispose();
    _discountPercentController.dispose();
    _cashReceivedController.dispose();

    super.dispose();
  }

  void _addToCart(String productId) {
    final provider = context.read<ProductProvider>();
    final product = provider.findById(productId);

    if (product == null) {
      return;
    }

    final currentQuantity = _cartQuantities[productId] ?? 0;

    if (currentQuantity >= product.stock) {
      return;
    }

    setState(() {
      _cartQuantities[productId] = currentQuantity + 1;
    });
  }

  void _decrementQuantity(String productId) {
    setState(() {
      final quantity = _cartQuantities[productId];

      if (quantity == null) {
        return;
      }

      if (quantity > 1) {
        _cartQuantities[productId] = quantity - 1;
      } else {
        _cartQuantities.remove(productId);
      }
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      _cartQuantities.remove(productId);
    });
  }

  void _clearCart() {
    setState(() {
      _cartQuantities.clear();

      _discountAmountController.clear();
      _discountPercentController.clear();
      _cashReceivedController.clear();

      _selectedDebtor = null;
    });
  }

  double get _subtotal {
    final provider = context.read<ProductProvider>();

    double total = 0;

    for (final entry in _cartQuantities.entries) {
      final product = provider.findById(entry.key);

      if (product == null) {
        continue;
      }

      total += product.price * entry.value;
    }

    return total;
  }

  double get _discountAmount {
    return double.tryParse(_discountAmountController.text) ?? 0;
  }

  double get _cardFeeAmount {
    if (_selectedPaymentMethod != AppPaymentMethods.card) {
      return 0;
    }

    final amount = _subtotal - _discountAmount;

    if (amount <= 0) {
      return 0;
    }

    return amount * AppInventory.cardFeePercentage;
  }

  double get _total {
    final total = _subtotal - _discountAmount + _cardFeeAmount;

    return total < 0 ? 0 : total;
  }

  double get _change {
    final cash = double.tryParse(_cashReceivedController.text) ?? 0;

    final change = cash - _total;

    return change > 0 ? change : 0;
  }

  void _onNavigationChanged(int index) {
    setState(() {
      _selectedNavIndex = index;
    });
  }

  void _onCategoryChanged(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().productMaps;

    return Scaffold(
      backgroundColor: AppColors.inputBackground,
      body: SafeArea(
        child: Row(
          children: [
            SidebarDrawer(
              isExpanded: _isSidebarExpanded,
              selectedIndex: _selectedNavIndex,
              onToggleExpand: () {
                setState(() {
                  _isSidebarExpanded = !_isSidebarExpanded;
                });
              },
              onItemSelected: _onNavigationChanged,
            ),
            Expanded(child: _buildMainContent(products)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(List<Map<String, dynamic>> products) {
    if (_selectedNavIndex == AppNavigation.inventory) {
      return const InventoryLayout();
    }

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: CentralProductGrid(
              products: products,
              cartQuantities: _cartQuantities,
              categories: _categories,
              selectedCategoryIndex: _selectedCategoryIndex,
              onCategorySelected: _onCategoryChanged,
              onAddToCart: _addToCart,
              onRemoveFromCart: _removeFromCart,
            ),
          ),
          const SizedBox(width: AppDimensions.productGridSpacing),
          Expanded(
            flex: 1,
            child: SalesSummaryPanel(
              cartQuantities: _cartQuantities,
              products: products,
              selectedPaymentMethod: _selectedPaymentMethod,
              onPaymentMethodChanged: (method) {
                setState(() {
                  _selectedPaymentMethod = method;
                });
              },
              selectedDebtor: _selectedDebtor,
              debtorsList: _debtors,
              onDebtorChanged: (debtor) {
                setState(() {
                  _selectedDebtor = debtor;
                });
              },
              discountAmountController: _discountAmountController,
              discountPercentController: _discountPercentController,
              cashReceivedController: _cashReceivedController,
              onDiscountAmountChanged: (_) {
                setState(() {});
              },
              onDiscountPercentChanged: (_) {
                setState(() {});
              },
              onCashReceivedChanged: (_) {
                setState(() {});
              },
              subtotal: _subtotal,
              cardFeeAmount: _cardFeeAmount,
              total: _total,
              change: _change,
              onAddToCart: _addToCart,
              onDecrementQuantity: _decrementQuantity,
              onRemoveFromCart: _removeFromCart,
              onClearCart: _clearCart,
            ),
          ),
        ],
      ),
    );
  }
}
