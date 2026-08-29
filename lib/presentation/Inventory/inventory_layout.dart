import 'package:flutter/material.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/presentation/widgets/category_selector.dart';

class InventoryLayout extends StatefulWidget {
  const InventoryLayout({super.key});

  @override
  State<InventoryLayout> createState() => _InventoryLayoutState();
}

class _InventoryLayoutState extends State<InventoryLayout> {
  int _selectedCategoryIndex = 0;

  final List<String> _categories = [
    'Todos',
    'Bebidas',
    'Snacks',
    'Abarrotes',
    'Lácteos',
    'Limpieza',
    'Cuidado Personal',
  ];

  final List<Map<String, dynamic>> _allInventoryProducts = [
    {
      'name': 'Coca Cola 600ml',
      'cost': 0.63,
      'price': 0.80,
      'stock': 10,
      'category': 'Bebidas',
    },
    {
      'name': 'Papas Lays 45g',
      'cost': 0.45,
      'price': 0.65,
      'stock': 24,
      'category': 'Snacks',
    },
    {
      'name': 'Leche Salud 1L',
      'cost': 1.10,
      'price': 1.35,
      'stock': 12,
      'category': 'Lácteos',
    },
    {
      'name': 'Agua Cristal 1.5L',
      'cost': 0.40,
      'price': 0.60,
      'stock': 18,
      'category': 'Bebidas',
    },
  ];

  List<Map<String, dynamic>> get _filteredProducts {
    if (_selectedCategoryIndex == 0) return _allInventoryProducts;
    final selectedCategory = _categories[_selectedCategoryIndex];
    return _allInventoryProducts
        .where((p) => p['category'] == selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Buscador + Métricas
          _buildTopHeader(),

          const SizedBox(height: 12),

          // 2. Selector Reutilizable de Categorías
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

          // 3. Tabla de Productos con Encabezados Visibles
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // --- FILA DE ENCABEZADOS DE LA TABLA ---
                  _buildTableHeader(),
                  const Divider(height: 1, color: AppColors.border),

                  // --- CUERPO DE LA TABLA ---
                  Expanded(
                    child: _buildInventoryList(_filteredProducts),
                  ),
                ],
              ),
            ),
          ),
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
                vertical: 0,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildMetricCard(
          '\$37.50',
          'Inversión total',
          AppColors.textPrimary,
        ),
        const SizedBox(width: 8),
        _buildMetricCard('\$50.60', 'Venta total', AppColors.primary),
        const SizedBox(width: 8),
        _buildMetricCard(
          '\$13.10',
          'Ganancia total',
          AppColors.successGreen,
        ),
      ],
    );
  }

  Widget _buildMetricCard(String amount, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    );

    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 40,
          ), // Espacio alineado con el icono de la foto
          SizedBox(width: 12),
          Expanded(flex: 3, child: Text('Producto', style: style)),
          Expanded(flex: 2, child: Text('Costo', style: style)),
          Expanded(flex: 2, child: Text('P. Venta', style: style)),
          Expanded(
            flex: 2,
            child: Text('Cant. disponible', style: style),
          ),
          Expanded(flex: 2, child: Text('Ganancia', style: style)),
          Expanded(flex: 1, child: Text('%', style: style)),
        ],
      ),
    );
  }

  Widget _buildInventoryList(List<Map<String, dynamic>> products) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'No hay productos en esta categoría',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: products.length,
      separatorBuilder: (context, index) =>
          const Divider(color: AppColors.chipBackground),
      itemBuilder: (context, index) {
        final p = products[index];
        final cost = p['cost'] as double;
        final price = p['price'] as double;
        final profit = price - cost;
        final profitPercent = ((profit / cost) * 100).toStringAsFixed(
          0,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
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
                  p['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '\$${cost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${p['stock']}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '\$${profit.toStringAsFixed(2)}',
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
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
