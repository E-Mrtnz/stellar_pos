import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/utils/product_utils.dart';

/// Reusable cart row used by the desktop sales summary and the mobile scanner.
class SalesCartItemTile extends StatelessWidget {
  final String productId;
  final String name;
  final String unit;
  final double unitPrice;
  final String imageData;
  final int quantity;
  final Map<String, dynamic> product;
  final bool prepared;
  final VoidCallback onDecrement;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  const SalesCartItemTile({
    super.key,
    required this.productId,
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.imageData,
    required this.quantity,
    required this.product,
    this.prepared = false,
    required this.onDecrement,
    required this.onQuantityChanged,
    required this.onIncrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final preparationExtra =
        ProductUtils.asDouble(product['preparationExtra']);
    final subtotalItem = prepared
        ? (ProductUtils.price(product) + preparationExtra) * quantity
        : ProductUtils.priceForQuantity(product, quantity);

    return Container(
      height: 76,
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 8,
            bottom: 8,
            child: _buildImage(),
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
                  unit.trim().isEmpty
                      ? product['brand']?.toString() ?? ''
                      : product['brand']?.toString().trim().isEmpty ?? true
                          ? unit
                          : '$unit | ${product['brand']}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                  _buildQtyButton(Icons.remove, onDecrement),
                  _QuantityInput(
                    quantity: quantity,
                    onChanged: onQuantityChanged,
                  ),
                  _buildQtyButton(Icons.add, onIncrement),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Text(
              subtotalItem.toStringAsFixed(2),
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
              onTap: onRemove,
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

  Widget _buildImage() {
    if (imageData.trim().isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(imageData),
            width: 56,
            height: 60,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {}
    }
    return Container(
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
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 20,
          height: 20,
          child: Icon(icon, size: 13, color: AppColors.primary),
        ),
      );
}

class _QuantityInput extends StatefulWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantityInput({
    required this.quantity,
    required this.onChanged,
  });

  @override
  State<_QuantityInput> createState() => _QuantityInputState();
}

class _QuantityInputState extends State<_QuantityInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.quantity.toString());
  }

  @override
  void didUpdateWidget(covariant _QuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity &&
        _controller.text != widget.quantity.toString()) {
      _controller.value = TextEditingValue(
        text: widget.quantity.toString(),
        selection: TextSelection.collapsed(
          offset: widget.quantity.toString().length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final quantity = int.tryParse(value);
    if (quantity != null && quantity > 0) {
      widget.onChanged(quantity);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 34,
        height: 20,
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: _handleChanged,
        ),
      );
}
