import 'package:flutter/material.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/presentation/inventory/inventory_layout.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/central_product_grid.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sales_summary_panel.dart';

class MainDashboardLayout extends StatefulWidget {
  const MainDashboardLayout({super.key});

  @override
  State<MainDashboardLayout> createState() =>
      _MainDashboardLayoutState();
}

class _MainDashboardLayoutState extends State<MainDashboardLayout> {
  int _selectedNavIndex = 0;
  int _selectedCategoryIndex = 0;
  bool _isSidebarCollapsed =
      false; // Permite encoger/agrandar el menú lateral

  // --- ESTADO DEL CARRITO Y PAGOS ---
  final Map<String, int> _cartQuantities = {};
  int _selectedPaymentMethod =
      0; // 0: Efectivo, 1: Tarjeta, 2: Transferencia, 3: Fiado
  String? _selectedDebtor;

  final List<String> _categories = [
    'Todos',
    'Bebidas',
    'Snacks',
    'Abarrotes',
    'Lácteos',
    'Limpieza',
    'Cuidado Personal',
  ];

  final List<String> _debtorsList = [
    'Juan Pérez',
    'María López',
    'Carlos Gómez',
    'Ana Martínez',
  ];

  // Controladores de texto
  final TextEditingController _discountAmountController =
      TextEditingController();
  final TextEditingController _discountPercentController =
      TextEditingController();
  final TextEditingController _cashReceivedController =
      TextEditingController();

  // Productos del POS
  final List<Map<String, dynamic>> _productsList = [
    {
      'id': '1',
      'name': 'Coca Cola 354ml',
      'price': 0.80,
      'stock': 24,
      'category': 'Bebidas',
    },
    {
      'id': '2',
      'name': 'Papas Lays 45g',
      'price': 0.65,
      'stock': 15,
      'category': 'Snacks',
    },
    {
      'id': '3',
      'name': 'Arroz San Pedro 1lb',
      'price': 0.75,
      'stock': 40,
      'category': 'Abarrotes',
    },
    {
      'id': '4',
      'name': 'Leche Salud 1L',
      'price': 1.35,
      'stock': 8,
      'category': 'Lácteos',
    },
    {
      'id': '5',
      'name': 'Jabón Axion 250g',
      'price': 0.90,
      'stock': 12,
      'category': 'Limpieza',
    },
    {
      'id': '6',
      'name': 'Shampoo Savilé 750ml',
      'price': 3.50,
      'stock': 6,
      'category': 'Cuidado Personal',
    },
  ];

  @override
  void dispose() {
    _discountAmountController.dispose();
    _discountPercentController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  // --- MÉTODOS DEL CARRITO ---
  void _addToCart(String productId) {
    setState(() {
      _cartQuantities[productId] =
          (_cartQuantities[productId] ?? 0) + 1;
    });
  }

  void _decrementQuantity(String productId) {
    setState(() {
      if (_cartQuantities.containsKey(productId)) {
        if (_cartQuantities[productId]! > 1) {
          _cartQuantities[productId] = _cartQuantities[productId]! - 1;
        } else {
          _cartQuantities.remove(productId);
        }
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
      _discountAmountController;
      _discountPercentController;
      _cashReceivedController;
      _selectedDebtor = null;
    });
  }

  // --- CÁLCULOS FINANCIEROS EN TIEMPO REAL ---
  double get _subtotal {
    double total = 0.0;
    _cartQuantities.forEach((id, qty) {
      final product = _productsList.firstWhere(
        (p) => p['id'] == id,
        orElse: () => {'price': 0.0},
      );
      total += (product['price'] as double) * qty;
    });
    return total;
  }

  double get _discountAmount {
    return double.tryParse(_discountAmountController.text) ?? 0.0;
  }

  double get _cardFeeAmount {
    if (_selectedPaymentMethod == 1) {
      return (_subtotal - _discountAmount) * 0.05;
    }
    return 0.0;
  }

  double get _total {
    final computed = _subtotal - _discountAmount + _cardFeeAmount;
    return computed < 0 ? 0.0 : computed;
  }

  double get _change {
    final cash = double.tryParse(_cashReceivedController.text) ?? 0.0;
    final changeVal = cash - _total;
    return changeVal > 0 ? changeVal : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inputBackground,
      body: SafeArea(
        child: Row(
          children: [
            // 1. Menú Lateral Fijo con opción a Encoger/Agrandar
            _buildNavigationSidebar(),

            // 2. Área Principal Dinámica
            Expanded(
              child: _selectedNavIndex == 1
                  ? const InventoryLayout()
                  : Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // Panel Central: Malla de Productos POS
                          Expanded(
                            flex: 3,
                            child: CentralProductGrid(
                              products: _productsList,
                              cartQuantities: _cartQuantities,
                              categories: _categories,
                              selectedCategoryIndex:
                                  _selectedCategoryIndex,
                              onCategorySelected: (index) {
                                setState(() {
                                  _selectedCategoryIndex = index;
                                });
                              },
                              onAddToCart: _addToCart,
                              onRemoveFromCart: _removeFromCart,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Panel Derecho: Resumen de Ventas
                          Expanded(
                            flex: 1,
                            child: SalesSummaryPanel(
                              cartQuantities: _cartQuantities,
                              products: _productsList,
                              selectedPaymentMethod:
                                  _selectedPaymentMethod,
                              onPaymentMethodChanged: (method) {
                                setState(() {
                                  _selectedPaymentMethod = method;
                                });
                              },
                              selectedDebtor: _selectedDebtor,
                              debtorsList: _debtorsList,
                              onDebtorChanged: (debtor) {
                                setState(() {
                                  _selectedDebtor = debtor;
                                });
                              },
                              discountAmountController:
                                  _discountAmountController,
                              discountPercentController:
                                  _discountPercentController,
                              cashReceivedController:
                                  _cashReceivedController,
                              onDiscountAmountChanged: (val) {
                                setState(() {});
                              },
                              onDiscountPercentChanged: (val) {
                                setState(() {});
                              },
                              onCashReceivedChanged: (val) {
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
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- NAVEGACIÓN LATERAL COLAPSABLE ---
  Widget _buildNavigationSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isSidebarCollapsed ? 70 : 200,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        color: AppColors.sidebarBackground,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Cabecera con botón para Encoger/Agrandar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 16.0,
            ),
            child: Row(
              mainAxisAlignment: _isSidebarCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!_isSidebarCollapsed)
                  const Row(
                    children: [
                      Icon(
                        Icons.storefront,
                        color: AppColors.primary,
                        size: 26,
                      ),
                      SizedBox(width: 8),
                      Text(
                        AppStrings.appName,
                        style: AppTextStyles.brandTitle,
                      ),
                    ],
                  ),
                IconButton(
                  icon: Icon(
                    _isSidebarCollapsed
                        ? Icons.chevron_right
                        : Icons.chevron_left,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSidebarCollapsed = !_isSidebarCollapsed;
                    });
                  },
                  tooltip: _isSidebarCollapsed
                      ? 'Expandir menú'
                      : 'Encoger menú',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          _buildNavItem(
            0,
            Icons.home_outlined,
            Icons.home,
            AppStrings.navHome,
          ),
          _buildNavItem(
            1,
            Icons.inventory_2_outlined,
            Icons.inventory_2,
            AppStrings.navInventory,
          ),
          _buildNavItem(
            2,
            Icons.bar_chart_outlined,
            Icons.bar_chart,
            AppStrings.navStats,
          ),
          _buildNavItem(
            3,
            Icons.shopping_bag_outlined,
            Icons.shopping_bag,
            AppStrings.navPurchases,
          ),
          const Spacer(),
          _buildNavItem(
            4,
            Icons.settings_outlined,
            Icons.settings,
            AppStrings.navSettings,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _selectedNavIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedNavIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryLight
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: _isSidebarCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 20,
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
