import 'package:flutter/material.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';

class MainDashboardLayout extends StatefulWidget {
  const MainDashboardLayout({super.key});

  @override
  State<MainDashboardLayout> createState() =>
      _MainDashboardLayoutState();
}

class _MainDashboardLayoutState extends State<MainDashboardLayout> {
  bool _isSidebarExpanded = true;
  int _selectedIndex = 0;
  int _selectedTagIndex = 0;

  // Métodos de pago (0: Efectivo, 1: Tarjeta, 2: Transferencia, 3: Pendiente)
  int _selectedPaymentMethod = 0;
  String? _selectedDebtor;

  // Controladores
  final TextEditingController _discountAmountController =
      TextEditingController();
  final TextEditingController _discountPercentController =
      TextEditingController();
  final TextEditingController _cashReceivedController =
      TextEditingController();

  // Tarifas
  final double _cardFeeRate = 0.0557; // 5.57%
  double _discountAmount = 0.0;
  double _cashReceived = 0.0;

  final List<String> _dynamicCategories = [
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

  // Catálogo de productos disponible
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

  // Estado del Carrito de Compras: Map<String, int> (productId -> cantidad)
  final Map<String, int> _cartQuantities = {'p1': 2};

  // Obtener subtotal dinámico del carrito
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

  // Métodos de manipulación del carrito
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
              _buildSidebarCard(),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: _buildCentralCard()),
              const SizedBox(width: 12),
              Expanded(flex: 1, child: _buildRightSummaryCard()),
            ],
          ),
        ),
      ),
    );
  }

  // --- CARD IZQUIERDA ---
  Widget _buildSidebarCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _isSidebarExpanded ? 220 : 72,
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
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    if (_isSidebarExpanded) ...[
                      const SizedBox(width: 12),
                      const Text(
                        AppStrings.appName,
                        style: AppTextStyles.brandTitle,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildSidebarItem(
                      0,
                      Icons.home_rounded,
                      AppStrings.navHome,
                    ),
                    _buildSidebarItem(
                      1,
                      Icons.inventory_2_rounded,
                      AppStrings.navInventory,
                    ),
                    _buildSidebarItem(
                      2,
                      Icons.bar_chart_rounded,
                      AppStrings.navStats,
                    ),
                    _buildSidebarItem(
                      3,
                      Icons.shopping_bag_rounded,
                      AppStrings.navPurchases,
                    ),
                  ],
                ),
              ),
              const Divider(
                indent: 16,
                endIndent: 16,
                height: 1,
                color: AppColors.border,
              ),
              const SizedBox(height: 10),
              _buildSidebarItem(
                4,
                Icons.settings_rounded,
                AppStrings.navSettings,
              ),
              const SizedBox(height: 16),
            ],
          ),
          Positioned(
            top: 20,
            right: 8,
            child: InkWell(
              onTap: () {
                setState(() {
                  _isSidebarExpanded = !_isSidebarExpanded;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.border,
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  _isSidebarExpanded
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 22,
            ),
            if (_isSidebarExpanded) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.sidebarItem.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            if (isSelected)
              Container(
                width: 4,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- CARD CENTRAL CON GRID DE PRODUCTOS ---
  Widget _buildCentralCard() {
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

          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _dynamicCategories.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final isSelected = _selectedTagIndex == index;
                return ChoiceChip(
                  label: Text(_dynamicCategories[index]),
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
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedTagIndex = index;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),

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
              itemCount: _sampleProducts.length,
              itemBuilder: (context, index) {
                final product = _sampleProducts[index];
                return _buildProductCard(product);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- TARJETA INDIVIDUAL DE PRODUCTO EN PANEL CENTRAL ---
  Widget _buildProductCard(Map<String, dynamic> product) {
    final String productId = product['id'] as String;
    final int countInCart = _cartQuantities[productId] ?? 0;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Toda la tarjeta es cliqueable para agregar/sumar unidades
          InkWell(
            onTap: () => _addToCart(productId),
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
                            // Indicador dinámico 'XN'
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

          // BOTÓN DE ELIMINAR (Esquina Superior Derecha del ProductCard Central)
          if (countInCart > 0)
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: () => _removeFromCart(productId),
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

  // --- CARD DERECHA: RESUMEN DE VENTAS ---
  Widget _buildRightSummaryCard() {
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
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                AppStrings.salesSummaryTitle,
                style: AppTextStyles.sectionTitle,
              ),
              Icon(
                Icons.shopping_cart_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                AppStrings.ticketNumberLabel,
                style: AppTextStyles.ticketLabel,
              ),
              Text('#000102', style: AppTextStyles.ticketValue),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 6),

          // Lista de productos del resumen de venta
          Expanded(
            child: _cartQuantities.isEmpty
                ? const Center(
                    child: Text(
                      'Carrito vacío',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: _cartQuantities.entries.map((entry) {
                      final product = _sampleProducts.firstWhere(
                        (p) => p['id'] == entry.key,
                      );
                      return _buildCartItemTile(
                        productId: product['id'] as String,
                        name: product['name'] as String,
                        unitPrice: product['price'] as double,
                        quantity: entry.value,
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 6),

          // --- DETALLES DE PAGO ---
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Detalles de Pago',
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    _buildPaymentCardIconOnly(
                      0,
                      Icons.payments_outlined,
                      'Efectivo',
                    ),
                    const SizedBox(width: 4),
                    _buildPaymentCardIconOnly(
                      1,
                      Icons.credit_card_outlined,
                      'Tarjeta',
                    ),
                    const SizedBox(width: 4),
                    _buildPaymentCardIconOnly(
                      2,
                      Icons.account_balance_outlined,
                      'Transferencia',
                    ),
                    const SizedBox(width: 4),
                    _buildPaymentCardIconOnly(
                      3,
                      Icons.pending_actions_outlined,
                      'Pendiente',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_selectedPaymentMethod == 3) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDebtor ?? _debtorsList.first,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                    ),
                    items: _debtorsList.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDebtor = val;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                ],

                _buildSummaryRow(
                  'Subtotal',
                  '\$${_subtotal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 4),

                Row(
                  children: [
                    const Text(
                      'Descuento',
                      style: AppTextStyles.ticketLabel,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 48,
                      height: 24,
                      child: TextField(
                        controller: _discountAmountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                        style: const TextStyle(fontSize: 10),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                        ),
                        onChanged: _onDiscountAmountChanged,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 44,
                      height: 24,
                      child: TextField(
                        controller: _discountPercentController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                        style: const TextStyle(fontSize: 10),
                        decoration: InputDecoration(
                          prefixText: '% ',
                          prefixStyle: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                        ),
                        onChanged: _onDiscountPercentChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                if (_selectedPaymentMethod == 1) ...[
                  _buildSummaryRow(
                    'Tarifa Tarjeta (5.57%)',
                    '\$${_cardFeeAmount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 4),
                ],

                if (_selectedPaymentMethod == 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cambio:',
                        style: AppTextStyles.ticketLabel,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 58,
                            height: 24,
                            child: TextField(
                              controller: _cashReceivedController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                prefixText: '\$ ',
                                prefixStyle: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    4,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _cashReceived =
                                      double.tryParse(val) ?? 0.0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '\$${_change.toStringAsFixed(2)}',
                            style: AppTextStyles.changeValue,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],

                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 4),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: AppTextStyles.totalLabel,
                    ),
                    Text(
                      '\$${_total.toStringAsFixed(2)}',
                      style: AppTextStyles.totalValue,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      AppStrings.createSaleButton,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCardIconOnly(
    int index,
    IconData icon,
    String tooltip,
  ) {
    final isSelected = _selectedPaymentMethod == index;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedPaymentMethod = index;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 34,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withAlpha(20)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.ticketLabel),
        Text(value, style: AppTextStyles.ticketValue),
      ],
    );
  }

  // --- ITEM DEL CARRITO EN RESUMEN DE VENTAS ---
  Widget _buildCartItemTile({
    required String productId,
    required String name,
    required double unitPrice,
    required int quantity,
  }) {
    final double subtotalItem = unitPrice * quantity;

    return Container(
      height: 76,
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 8,
            bottom: 8,
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.image_outlined,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ),
          ),

          Positioned(
            left: 72,
            top: 8,
            right: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
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
                  '\$${unitPrice.toStringAsFixed(2)} c/u',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 72,
            bottom: 8,
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQtyBtn(
                    Icons.remove,
                    () => _decrementQuantity(productId),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                    ),
                    child: Text(
                      '$quantity',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildQtyBtn(Icons.add, () => _addToCart(productId)),
                ],
              ),
            ),
          ),

          Positioned(
            right: 12,
            bottom: 12,
            child: Text(
              '\$${subtotalItem.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),

          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              onTap: () => _removeFromCart(productId),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(10),
              ),
              child: Container(
                width: 36,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(244, 67, 54, 0.08),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(10),
                  ),
                  border: Border.all(
                    color: const Color.fromRGBO(244, 67, 54, 0.2),
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

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 10, color: AppColors.textPrimary),
      ),
    );
  }
}
