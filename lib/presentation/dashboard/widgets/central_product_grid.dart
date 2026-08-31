import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/presentation/widgets/category_selector.dart';

class CentralProductGrid extends StatelessWidget {
  final List<Map<String, dynamic>> products;

  final Map<String, int> cartQuantities;

  final List<String> categories;

  final int selectedCategoryIndex;

  final ValueChanged<int> onCategorySelected;

  final ValueChanged<String> onAddToCart;

  final ValueChanged<String> onRemoveFromCart;

  final TextEditingController? searchController;

  const CentralProductGrid({
    super.key,
    required this.products,
    required this.cartQuantities,
    required this.categories,
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    final filteredProducts = products.where((product) {
      if (selectedCategoryIndex == 0) return true;

      final categoryName = categories[selectedCategoryIndex];

      return product['category'] == categoryName;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: AppStrings.searchPlaceholder,
              hintStyle: AppTextStyles.searchHint,
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
              ),
              fillColor: AppColors.inputBackground,
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

          const SizedBox(height: 12),

          CategorySelector(
            categories: categories,
            selectedCategoryIndex: selectedCategoryIndex,
            onCategorySelected: onCategorySelected,
          ),

          const SizedBox(height: 12),

          const Divider(height: 1, color: AppColors.border),

          const SizedBox(height: 12),

          Expanded(
            child: filteredProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron productos',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : GridView.builder(
                    itemCount: filteredProducts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.82,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];

                      final productId = product['id'].toString();

                      final quantityInCart =
                          cartQuantities[productId] ?? 0;

                      return _buildProductCard(
                        product: product,
                        quantityInCart: quantityInCart,
                        onTap: () => onAddToCart(productId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required Map<String, dynamic> product,
    required int quantityInCart,
    required VoidCallback onTap,
  }) {
    final bool hasItemsInCart = quantityInCart > 0;

    final int stock = _getIntValue(product['stock'], fallback: 0);

    final int minStock = _getIntValue(product['minStock'], fallback: 5);

    /*
      Estado del inventario:

      ROJO:
      stock <= stock mínimo

      NARANJA:
      stock > mínimo
      y stock <= mínimo * 2

      VERDE:
      stock > mínimo * 2

      Ejemplo:
      mínimo = 5

      5 o menos  -> rojo
      6 a 10     -> naranja
      11 o más   -> verde
    */
    final Color stockColor = _getStockColor(
      stock: stock,
      minStock: minStock,
    );

    final String productName = _getProductName(product);

    final String unit = _getProductUnit(product);

    final String department = _getProductDepartment(product);

    final double price = _getDoubleValue(
      product['price'],
      fallback: 0.0,
    );

    return Material(
      color: AppColors.inputBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasItemsInCart
                  ? AppColors.primary
                  : AppColors.border,
              width: hasItemsInCart ? 1.5 : 1.0,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================================================
                  // IMAGEN / ICONO DEL PRODUCTO
                  // =========================================================
                  Expanded(
                    child: Container(
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
                          size: 36,
                        ),
                      ),
                    ),
                  ),

                  // =========================================================
                  // INFORMACIÓN DEL PRODUCTO
                  // =========================================================
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // -------------------------------------------------
                        // NOMBRE
                        // -------------------------------------------------
                        Text(
                          productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 2),

                        // -------------------------------------------------
                        // UNIDAD | DEPARTAMENTO
                        // -------------------------------------------------
                        Text(
                          '$unit | $department',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 7),

                        // -------------------------------------------------
                        // STOCK
                        // -------------------------------------------------
                        Row(
                          children: [
                            Container(
                              height: 26,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: stockColor.withAlpha(22),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: stockColor.withAlpha(100),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    color: stockColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$stock',
                                    style: TextStyle(
                                      color: stockColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 7),

                        // -------------------------------------------------
                        // PRECIO + CONTADOR DEL CARRITO
                        // -------------------------------------------------
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\$${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary,
                              ),
                            ),

                            // =================================================
                            // ESTE CONTADOR SE MANTIENE COMO CONTADOR
                            // DE PRODUCTOS AGREGADOS AL CARRITO.
                            // NO ES EL STOCK.
                            // =================================================
                            Container(
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
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add,
                                        color: AppColors.textSecondary,
                                        size: 14,
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

              // ===========================================================
              // BOTÓN ELIMINAR DEL CARRITO
              // ===========================================================
              //
              // Solo aparece cuando el producto ya fue agregado
              // al resumen de venta.
              //
              // Elimina completamente ese producto del carrito.
              // NO elimina el producto del inventario.
              //
              // ===========================================================
              if (hasItemsInCart)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        onRemoveFromCart(product['id'].toString());
                      },
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
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // COLOR DEL STOCK
  // =========================================================================

  Color _getStockColor({required int stock, required int minStock}) {
    if (stock <= minStock) {
      return AppColors.dangerRed;
    }

    final int warningStock = minStock * 2;

    if (stock <= warningStock) {
      return Colors.orange;
    }

    return Colors.green;
  }

  // =========================================================================
  // NOMBRE DEL PRODUCTO
  // =========================================================================

  String _getProductName(Map<String, dynamic> product) {
    final dynamic nameValue = product['name'];

    if (nameValue == null) {
      return '';
    }

    final String name = nameValue.toString().trim();

    /*
      Si el producto todavía tiene la unidad escrita dentro
      del nombre, por ejemplo:

      Coca Cola 354ml
      Papas Lays 45g
      Arroz San Pedro 1lb

      se elimina únicamente para la presentación de la Card.

      La unidad se muestra abajo mediante el campo "unit".
    */

    return name.replaceFirst(
      RegExp(
        r'\s+\d+(?:[.,]\d+)?\s*(?:ml|l|lt|litro|litros|g|gr|kg|lb|lbs|oz|unidad|unidades)\s*$',
        caseSensitive: false,
      ),
      '',
    );
  }

  // =========================================================================
  // UNIDAD DE MEDIDA
  // =========================================================================

  String _getProductUnit(Map<String, dynamic> product) {
    final dynamic unitValue = product['unit'];

    if (unitValue != null && unitValue.toString().trim().isNotEmpty) {
      return unitValue.toString().trim();
    }

    /*
      Compatibilidad con los datos actuales del proyecto.

      Mientras el producto todavía no tenga el campo "unit",
      intenta obtener la unidad desde el nombre antiguo.

      Ejemplo:

      "Coca Cola 354ml" -> "354ml"
    */

    final dynamic nameValue = product['name'];

    if (nameValue == null) {
      return '';
    }

    final String name = nameValue.toString().trim();

    final Match? match = RegExp(
      r'(\d+(?:[.,]\d+)?\s*(?:ml|l|lt|litro|litros|g|gr|kg|lb|lbs|oz|unidad|unidades))\s*$',
      caseSensitive: false,
    ).firstMatch(name);

    if (match != null) {
      return match.group(1)!.trim();
    }

    return '';
  }

  // =========================================================================
  // DEPARTAMENTO
  // =========================================================================

  String _getProductDepartment(Map<String, dynamic> product) {
    final dynamic departmentValue = product['department'];

    if (departmentValue != null &&
        departmentValue.toString().trim().isNotEmpty) {
      return departmentValue.toString().trim();
    }

    /*
      Compatibilidad temporal con los productos actuales.

      Si todavía no existe "department", se utiliza "category"
      como respaldo para evitar que la Card quede vacía.
    */

    final dynamic categoryValue = product['category'];

    if (categoryValue != null &&
        categoryValue.toString().trim().isNotEmpty) {
      return categoryValue.toString().trim();
    }

    return '';
  }

  // =========================================================================
  // CONVERSIÓN SEGURA A INT
  // =========================================================================

  int _getIntValue(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }

    return fallback;
  }

  // =========================================================================
  // CONVERSIÓN SEGURA A DOUBLE
  // =========================================================================

  double _getDoubleValue(dynamic value, {required double fallback}) {
    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }

    return fallback;
  }
}
