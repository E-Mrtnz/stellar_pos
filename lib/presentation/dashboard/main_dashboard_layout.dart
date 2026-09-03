import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/presentation/Inventory/inventory_layout.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/central_product_grid.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sales_summary_panel.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sidebar_drawer.dart';
import 'package:stellar_pos/presentation/electronic_balance/electronic_balance_layout.dart';
import 'package:stellar_pos/presentation/providers/providers_layout.dart';

class MainDashboardLayout extends StatefulWidget {
  const MainDashboardLayout({super.key});

  @override
  State<MainDashboardLayout> createState() => _MainDashboardLayoutState();
}

class _MainDashboardLayoutState extends State<MainDashboardLayout> {
  int _selectedNavIndex = AppNavigation.home;
  int _selectedTagIndex = 0;
  String? _selectedFilter;
  String _searchQuery = '';

  bool _isSidebarExpanded = true;

  final Map<String, int> _cartQuantities = {};

  String _barcodeBuffer = '';
  DateTime? _lastBarcodeInputAt;
  OverlayEntry? _productNotFoundOverlay;
  Timer? _productNotFoundTimer;

  int _selectedPaymentMethod = AppPaymentMethods.cash;
  String? _selectedDebtor;

  final TextEditingController _discountAmountController =
      TextEditingController();
  final TextEditingController _discountPercentController =
      TextEditingController();
  final TextEditingController _cashReceivedController =
      TextEditingController();

  List<String> get _tags => context.watch<CatalogProvider>().tags;

  List<String> get _debtors {
    return context
        .watch<CatalogProvider>()
        .clients
        .map((client) => client.name)
        .toList();
  }

  @override
  void dispose() {
    _productNotFoundTimer?.cancel();
    _productNotFoundOverlay?.remove();
    _discountAmountController.dispose();
    _discountPercentController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  KeyEventResult _handleBarcodeKey(FocusNode node, KeyEvent event) {
    if (_selectedNavIndex != AppNavigation.home || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;

    if (isEnter) {
      final barcode = _barcodeBuffer.trim();
      _barcodeBuffer = '';
      _lastBarcodeInputAt = null;

      if (barcode.isNotEmpty) {
        _handleScannedBarcode(barcode);
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    final character = event.character;

    if (character == null ||
        character.isEmpty ||
        character.trim().isEmpty) {
      return KeyEventResult.ignored;
    }

    final now = DateTime.now();
    final elapsed = _lastBarcodeInputAt == null
        ? null
        : now.difference(_lastBarcodeInputAt!).inMilliseconds;

    if (elapsed != null && elapsed > 200) {
      _barcodeBuffer = '';
    }

    _barcodeBuffer += character;
    _lastBarcodeInputAt = now;

    return KeyEventResult.ignored;
  }

  void _handleScannedBarcode(String barcode) {
    final product = context.read<ProductProvider>().findByBarcode(barcode);

    if (product != null) {
      _addToCart(product.id);
      return;
    }

    _showProductNotFoundAlert();
  }

  void _showProductNotFoundAlert() {
    if (!mounted) return;

    _productNotFoundTimer?.cancel();
    _productNotFoundOverlay?.remove();
    _productNotFoundOverlay = null;

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: MediaQuery.of(overlayContext).padding.top + 18,
          left: 20,
          right: 20,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: const _ProductNotFoundAlert(),
                ),
              ),
            ),
          ),
        );
      },
    );

    _productNotFoundOverlay = entry;
    overlay.insert(entry);

    _productNotFoundTimer = Timer(const Duration(seconds: 4), () {
      if (entry.mounted) {
        entry.remove();
      }

      if (identical(_productNotFoundOverlay, entry)) {
        _productNotFoundOverlay = null;
      }
    });
  }

  void _addToCart(String productId) {
    final provider = context.read<ProductProvider>();
    final product = provider.findById(productId);

    if (product == null) return;

    final currentQuantity = _cartQuantities[productId] ?? 0;

    setState(() {
      _cartQuantities[productId] = currentQuantity + 1;
    });
  }

  void _setCartQuantity(String productId, int quantity) {
    if (quantity <= 0) return;

    setState(() {
      _cartQuantities[productId] = quantity;
    });
  }

  void _decrementQuantity(String productId) {
    setState(() {
      final quantity = _cartQuantities[productId];
      if (quantity == null) return;

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
      if (product == null) continue;
      total += product.price * entry.value;
    }

    return total;
  }

  double get _discountAmount {
    return double.tryParse(_discountAmountController.text) ?? 0;
  }

  double get _cardFeeAmount {
    if (_selectedPaymentMethod != AppPaymentMethods.card) return 0;

    final amount = _subtotal - _discountAmount;
    if (amount <= 0) return 0;

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
    setState(() => _selectedNavIndex = index);
  }

  void _onTagChanged(int index) {
    setState(() => _selectedTagIndex = index);
  }

  void _onFilterChanged(String? filter) {
    setState(() => _selectedFilter = filter);
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().productMaps;

    return Scaffold(
      backgroundColor: AppColors.inputBackground,
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: _handleBarcodeKey,
          child: Row(
            children: [
              SidebarDrawer(
                isExpanded: _isSidebarExpanded,
                selectedIndex: _selectedNavIndex,
                onToggleExpand: () {
                  setState(() => _isSidebarExpanded = !_isSidebarExpanded);
                },
                onItemSelected: _onNavigationChanged,
              ),
              Expanded(child: _buildMainContent(products)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(List<Map<String, dynamic>> products) {
    if (_selectedNavIndex == AppNavigation.inventory) {
      return const InventoryLayout();
    }

    if (_selectedNavIndex == AppNavigation.electronicBalance) {
      return const ElectronicBalanceLayout();
    }

    if (_selectedNavIndex == AppNavigation.providers) {
      return const ProvidersLayout();
    }

    if (_selectedNavIndex != AppNavigation.home) {
      return const _EmptySectionPanel();
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
              tags: _tags,
              selectedTagIndex: _selectedTagIndex,
              onTagSelected: _onTagChanged,
              selectedFilter: _selectedFilter,
              onFilterChanged: _onFilterChanged,
              onAddToCart: _addToCart,
              onRemoveFromCart: _removeFromCart,
              searchQuery: _searchQuery,
              onSearchChanged: (value) {
                setState(() => _searchQuery = value);
              },
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
                setState(() => _selectedPaymentMethod = method);
              },
              selectedDebtor: _selectedDebtor,
              debtorsList: _debtors,
              onDebtorChanged: (debtor) {
                setState(() => _selectedDebtor = debtor);
              },
              discountAmountController: _discountAmountController,
              discountPercentController: _discountPercentController,
              cashReceivedController: _cashReceivedController,
              onDiscountAmountChanged: (_) => setState(() {}),
              onDiscountPercentChanged: (_) => setState(() {}),
              onCashReceivedChanged: (_) => setState(() {}),
              subtotal: _subtotal,
              cardFeeAmount: _cardFeeAmount,
              total: _total,
              change: _change,
              onAddToCart: _addToCart,
              onDecrementQuantity: _decrementQuantity,
              onQuantityChanged: _setCartQuantity,
              onRemoveFromCart: _removeFromCart,
              onClearCart: _clearCart,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionPanel extends StatelessWidget {
  const _EmptySectionPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

class _ProductNotFoundAlert extends StatelessWidget {
  const _ProductNotFoundAlert();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningOrange,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'Producto no encontrado',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
