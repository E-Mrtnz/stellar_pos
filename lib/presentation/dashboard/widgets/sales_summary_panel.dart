import 'package:flutter/material.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';

class SalesSummaryPanel extends StatelessWidget {
  final Map<String, int> cartQuantities;
  final List<Map<String, dynamic>> products;
  final int selectedPaymentMethod;
  final ValueChanged<int> onPaymentMethodChanged;
  final String? selectedDebtor;
  final List<String> debtorsList;
  final ValueChanged<String?> onDebtorChanged;
  final TextEditingController discountAmountController;
  final TextEditingController discountPercentController;
  final TextEditingController cashReceivedController;
  final ValueChanged<String> onDiscountAmountChanged;
  final ValueChanged<String> onDiscountPercentChanged;
  final ValueChanged<String> onCashReceivedChanged;
  final double subtotal;
  final double cardFeeAmount;
  final double total;
  final double change;
  final ValueChanged<String> onAddToCart;
  final ValueChanged<String> onDecrementQuantity;
  final ValueChanged<String> onRemoveFromCart;
  final VoidCallback onClearCart;

  const SalesSummaryPanel({
    super.key,
    required this.cartQuantities,
    required this.products,
    required this.selectedPaymentMethod,
    required this.onPaymentMethodChanged,
    required this.selectedDebtor,
    required this.debtorsList,
    required this.onDebtorChanged,
    required this.discountAmountController,
    required this.discountPercentController,
    required this.cashReceivedController,
    required this.onDiscountAmountChanged,
    required this.onDiscountPercentChanged,
    required this.onCashReceivedChanged,
    required this.subtotal,
    required this.cardFeeAmount,
    required this.total,
    required this.change,
    required this.onAddToCart,
    required this.onDecrementQuantity,
    required this.onRemoveFromCart,
    required this.onClearCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
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

          // Fila del Número de Factura y Botón "Borrar todo"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Text(
                    AppStrings.ticketNumberLabel,
                    style: AppTextStyles.ticketLabel,
                  ),
                  SizedBox(width: 4),
                  Text('#000102', style: AppTextStyles.ticketValue),
                ],
              ),

              // Botón "Borrar todo" (Silueta / Outlined)
              if (cartQuantities.isNotEmpty)
                SizedBox(
                  height: 26,
                  child: OutlinedButton.icon(
                    onPressed: onClearCart,
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      size: 14,
                      color: AppColors.dangerRed,
                    ),
                    label: const Text(
                      'Borrar todo',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dangerRed,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                      side: BorderSide(
                        color: AppColors.dangerRed.withAlpha(120),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 6),

          // Lista de Productos en el Carrito
          Expanded(
            child: cartQuantities.isEmpty
                ? const Center(
                    child: Text(
                      AppStrings.emptyCartMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: cartQuantities.entries.map((entry) {
                      final product = products.firstWhere(
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

          // Sección de Detalles de Pago
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

                // Iconos Métodos de Pago
                Row(
                  children: [
                    _buildPaymentCardIcon(
                      0,
                      Icons.payments_outlined,
                      'Efectivo',
                    ),
                    const SizedBox(width: 4),
                    _buildPaymentCardIcon(
                      1,
                      Icons.credit_card_outlined,
                      'Tarjeta',
                    ),
                    const SizedBox(width: 4),
                    _buildPaymentCardIcon(
                      2,
                      Icons.account_balance_outlined,
                      'Transferencia',
                    ),
                    const SizedBox(width: 4),
                    _buildPaymentCardIcon(
                      3,
                      Icons.pending_actions_outlined,
                      'Fiado',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Dropdown Deudor
                if (selectedPaymentMethod == 3) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedDebtor ?? debtorsList.first,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                    ),
                    items: debtorsList.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                    onChanged: onDebtorChanged,
                  ),
                  const SizedBox(height: 6),
                ],

                // Desglose Financiero
                _buildSummaryRow(
                  'Subtotal',
                  '\$${subtotal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 4),

                // Fila Descuento
                Row(
                  children: [
                    const Text(
                      'Descuento',
                      style: AppTextStyles.ticketLabel,
                    ),
                    const Spacer(),

                    SizedBox(
                      width: 56,
                      height: 24,
                      child: TextField(
                        controller: discountPercentController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                        style: const TextStyle(fontSize: 10),
                        decoration: InputDecoration(
                          prefixText: '% ',
                          hintText: '0',
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
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                        ),
                        onChanged: onDiscountPercentChanged,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 56,
                      height: 24,

                      child: TextField(
                        controller: discountAmountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                        style: const TextStyle(fontSize: 10),
                        decoration: InputDecoration(
                          hintText: '0.00',
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
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                        ),
                        onChanged: onDiscountAmountChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                if (selectedPaymentMethod == 1) ...[
                  _buildSummaryRow(
                    'Tarifa Tarjeta (5.57%)',
                    '\$${cardFeeAmount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 4),
                ],

                if (selectedPaymentMethod == 0) ...[
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
                              controller: cashReceivedController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(fontSize: 10),
                              decoration: InputDecoration(
                                prefixText: '\$ ',
                                hintText: '0.00',

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
                                fillColor: AppColors.cardBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    4,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                              ),
                              onChanged: onCashReceivedChanged,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '\$${change.toStringAsFixed(2)}',
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
                      '\$${total.toStringAsFixed(2)}',
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
                      foregroundColor: AppColors.cardBackground,
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

  Widget _buildPaymentCardIcon(
    int index,
    IconData icon,
    String tooltip,
  ) {
    final isSelected = selectedPaymentMethod == index;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => onPaymentMethodChanged(index),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 34,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withAlpha(20)
                  : AppColors.cardBackground,
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
        color: AppColors.cardBackground,
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
                    () => onDecrementQuantity(productId),
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
                  _buildQtyBtn(Icons.add, () => onAddToCart(productId)),
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
                color: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              onTap: () => onRemoveFromCart(productId),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(10),
              ),
              child: Container(
                width: 36,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withAlpha(20),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(10),
                  ),
                  border: Border.all(
                    color: AppColors.dangerRed.withAlpha(50),
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
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 10, color: AppColors.textPrimary),
      ),
    );
  }
}
