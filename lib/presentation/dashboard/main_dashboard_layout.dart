import 'package:flutter/material.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'widgets/sidebar_drawer.dart';
import 'widgets/central_product_grid.dart';
import 'widgets/sales_summary_panel.dart';

class MainDashboardLayout extends StatefulWidget {
  const MainDashboardLayout({super.key});

  @override
  State<MainDashboardLayout> createState() =>
      _MainDashboardLayoutState();
}

class _MainDashboardLayoutState extends State<MainDashboardLayout> {
  bool _isSidebarExpanded = true;
  int _selectedIndex = 0;
  int _selectedCategoryIndex = 0;

  int _selectedPaymentMethod = 0;
  String? _selectedDebtor;

  final TextEditingController _discountAmountController =
      TextEditingController();
  final TextEditingController _discountPercentController =
      TextEditingController();
  final TextEditingController _cashReceivedController =
      TextEditingController();

  final double _cardFeeRate = 0.0557; // 5.57%
  double _discountAmount = 0.0;
  double _cashReceived = 0.0;

  final List<String> _categories = [
    'Todos',
    'Bebidas',
    'Snacks',
    'Abarrotes',
    'Lácteos',
    'Limpieza',
    'Cuidado Personal',
    'Mascotas',
  ];

  final List<String> _debtorsList = [
    'Seleccionar Cliente...',
    'Juan Pérez',
    'María López',
    'Carlos Mendoza',
    'Ana Martínez',
  ];

  final List<Map<String, dynamic>> _sampleProducts = [
    {
      'id': 'p1',
      'name': 'Coca Cola 354ml',
      'price': 0.80,
      'category': 'Bebidas',
      'stock': 24,
    },
    {
      'id': 'p2',
      'name': 'Papas Lays 45g',
      'price': 0.65,
      'category': 'Snacks',
      'stock': 15,
    },
    {
      'id': 'p3',
      'name': 'Arroz San Pedro 1lb',
      'price': 0.75,
      'category': 'Abarrotes',
      'stock': 40,
    },
    {
      'id': 'p4',
      'name': 'Leche Salud 1L',
      'price': 1.35,
      'category': 'Lácteos',
      'stock': 8,
    },
    {
      'id': 'p5',
      'name': 'Jabón Axion 250g',
      'price': 0.90,
      'category': 'Limpieza',
      'stock': 12,
    },
    {
      'id': 'p6',
      'name': 'Shampoo Savilé 750ml',
      'price': 3.50,
      'category': 'Cuidado Personal',
      'stock': 6,
    },
  ];

  final Map<String, int> _cartQuantities = {'p1': 2};

  double get _subtotal {
    double total = 0.0;
    _cartQuantities.forEach((id, qty) {
      final product = _sampleProducts.firstWhere(
        (p) => p['id'] == id,
        orElse: () => {'price': 0.0},
      );
      total += (product['price'] as double) * qty;
    });
    return total;
  }

  void _addToCart(String productId) {
    setState(() {
      _cartQuantities[productId] =
          (_cartQuantities[productId] ?? 0) + 1;
    });
  }

  void _decrementQuantity(String productId) {
    setState(() {
      if ((_cartQuantities[productId] ?? 0) > 1) {
        _cartQuantities[productId] = _cartQuantities[productId]! - 1;
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

  @override
  void dispose() {
    _discountAmountController.dispose();
    _discountPercentController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  void _onDiscountAmountChanged(String val) {
    final amount = double.tryParse(val) ?? 0.0;
    setState(() {
      _discountAmount = amount;
      if (_subtotal > 0) {
        final percent = (amount / _subtotal) * 100;
        _discountPercentController.text = percent > 0
            ? percent.toStringAsFixed(1)
            : '';
      }
    });
  }

  void _onDiscountPercentChanged(String val) {
    final percent = double.tryParse(val) ?? 0.0;
    setState(() {
      _discountAmount = (_subtotal * percent) / 100;
      _discountAmountController.text = _discountAmount > 0
          ? _discountAmount.toStringAsFixed(2)
          : '';
    });
  }

  double get _cardFeeAmount {
    if (_selectedPaymentMethod != 1) return 0.0;
    final base = _subtotal - _discountAmount;
    return base > 0 ? base * _cardFeeRate : 0.0;
  }

  double get _total {
    double base = _subtotal - _discountAmount;
    if (base < 0) base = 0;
    return base + _cardFeeAmount;
  }

  double get _change {
    if (_cashReceived <= 0 || _cashReceived < _total) return 0.0;
    return _cashReceived - _total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // 1. PANEL IZQUIERDO
              SidebarDrawer(
                isExpanded: _isSidebarExpanded,
                selectedIndex: _selectedIndex,
                onToggleExpand: () => setState(
                  () => _isSidebarExpanded = !_isSidebarExpanded,
                ),
                onItemSelected: (index) =>
                    setState(() => _selectedIndex = index),
              ),
              const SizedBox(width: 12),

              // 2. PANEL CENTRAL
              Expanded(
                flex: 3,
                child: CentralProductGrid(
                  categories: _categories,
                  selectedCategoryIndex: _selectedCategoryIndex,
                  onCategorySelected: (index) =>
                      setState(() => _selectedCategoryIndex = index),
                  products: _sampleProducts,
                  cartQuantities: _cartQuantities,
                  onAddToCart: _addToCart,
                  onRemoveFromCart: _removeFromCart,
                ),
              ),
              const SizedBox(width: 12),

              // 3. PANEL DERECHO
              Expanded(
                flex: 1,
                child: SalesSummaryPanel(
                  onClearCart: () {
                    setState(() {
                      _cartQuantities.clear();
                      _discountAmount = 0.0;
                      _discountAmountController.clear();
                      _discountPercentController.clear();
                    });
                  },
                  cartQuantities: _cartQuantities,
                  products: _sampleProducts,
                  selectedPaymentMethod: _selectedPaymentMethod,
                  onPaymentMethodChanged: (method) =>
                      setState(() => _selectedPaymentMethod = method),
                  selectedDebtor: _selectedDebtor,
                  debtorsList: _debtorsList,
                  onDebtorChanged: (debtor) =>
                      setState(() => _selectedDebtor = debtor),
                  discountAmountController: _discountAmountController,
                  discountPercentController: _discountPercentController,
                  cashReceivedController: _cashReceivedController,
                  onDiscountAmountChanged: _onDiscountAmountChanged,
                  onDiscountPercentChanged: _onDiscountPercentChanged,
                  onCashReceivedChanged: (val) => setState(
                    () => _cashReceived = double.tryParse(val) ?? 0.0,
                  ),
                  subtotal: _subtotal,
                  cardFeeAmount: _cardFeeAmount,
                  total: _total,
                  change: _change,
                  onAddToCart: _addToCart,
                  onDecrementQuantity: _decrementQuantity,
                  onRemoveFromCart: _removeFromCart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
