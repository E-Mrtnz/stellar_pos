import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';

class EditCreditSaleDialog extends StatefulWidget {
  final SaleRecord sale;

  const EditCreditSaleDialog({super.key, required this.sale});

  static Future<List<SaleItemRecord>?> show(
    BuildContext context, {
    required SaleRecord sale,
  }) {
    return showDialog<List<SaleItemRecord>>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: EditCreditSaleDialog(sale: sale),
      ),
    );
  }

  @override
  State<EditCreditSaleDialog> createState() => _EditCreditSaleDialogState();
}

class _EditCreditSaleDialogState extends State<EditCreditSaleDialog> {
  final TextEditingController _searchController = TextEditingController();
  late final Map<String, int> _quantities;
  String _query = '';

  bool get _hasElectronicItems =>
      widget.sale.items.any((item) => item.isElectronicBalance);

  @override
  void initState() {
    super.initState();
    _quantities = {
      for (final item in widget.sale.items)
        if (!item.isElectronicBalance) item.productId: item.quantity,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filteredProducts(ProductProvider provider) {
    final query = _query.trim().toLowerCase();
    final products = provider.products.where((product) {
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query);
    }).toList();
    products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return products;
  }

  List<SaleItemRecord> _buildItems(ProductProvider provider) {
    final items = <SaleItemRecord>[];

    for (final oldItem in widget.sale.items) {
      if (oldItem.isElectronicBalance) {
        items.add(oldItem);
        continue;
      }

      final quantity = _quantities[oldItem.productId] ?? 0;
      if (quantity <= 0) continue;
      final product = provider.findById(oldItem.productId);
      if (product == null) continue;

      final lineSubtotal = product.price * quantity;
      items.add(
        SaleItemRecord(
          productId: product.id,
          productName: product.name,
          unit: product.unit,
          barcode: product.barcode,
          cost: product.cost,
          unitPrice: product.price,
          quantity: quantity,
          lineSubtotal: lineSubtotal,
          discount: 0,
          lineTotal: lineSubtotal,
          imageData: product.imageData,
        ),
      );
    }

    for (final entry in _quantities.entries) {
      if (widget.sale.items.any((item) => item.productId == entry.key) ||
          entry.value <= 0) {
        continue;
      }
      final product = provider.findById(entry.key);
      if (product == null) continue;
      final lineSubtotal = product.price * entry.value;
      items.add(
        SaleItemRecord(
          productId: product.id,
          productName: product.name,
          unit: product.unit,
          barcode: product.barcode,
          cost: product.cost,
          unitPrice: product.price,
          quantity: entry.value,
          lineSubtotal: lineSubtotal,
          discount: 0,
          lineTotal: lineSubtotal,
          imageData: product.imageData,
        ),
      );
    }

    return items;
  }

  double _subtotal(List<SaleItemRecord> items) =>
      items.fold(0, (sum, item) => sum + item.lineSubtotal);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final products = _filteredProducts(provider);
    final selectedCount = _quantities.values.fold<int>(0, (sum, value) => sum + value);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Editar venta fiada', style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 2),
                        Text(
                          'Ticket #${widget.sale.ticketNumber} · ${widget.sale.clientName}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            if (_hasElectronicItems)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange.withAlpha(12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.warningOrange.withAlpha(35)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 17, color: AppColors.warningOrange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Las recargas electrónicas de esta venta se conservan sin cambios. Aquí puedes corregir los productos físicos.',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Buscar producto para agregar...',
                  prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear, size: 17),
                        ),
                ),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, index) {
                        final product = products[index];
                        final quantity = _quantities[product.id] ?? 0;
                        return _ProductOption(
                          product: product,
                          quantity: quantity,
                          onAdd: () => setState(
                            () => _quantities[product.id] = quantity + 1,
                          ),
                        );
                      },
                    ),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(
                    child: _CurrentItemsPanel(
                      items: _buildItems(provider),
                      quantities: _quantities,
                      onIncrement: (id) => setState(
                        () => _quantities[id] = (_quantities[id] ?? 0) + 1,
                      ),
                      onDecrement: (id) => setState(() {
                        final value = _quantities[id] ?? 0;
                        if (value <= 1) {
                          _quantities.remove(id);
                        } else {
                          _quantities[id] = value - 1;
                        }
                      }),
                      onRemove: (id) => setState(() => _quantities.remove(id)),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(
                children: [
                  Text('$selectedCount unidades', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _quantities.isEmpty && !_hasElectronicItems
                        ? null
                        : () => Navigator.of(context).pop(_buildItems(provider)),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Revisar cambios'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductOption extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback onAdd;

  const _ProductOption({required this.product, required this.quantity, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                Text('\$${product.price.toStringAsFixed(2)} · ${product.unit}', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (quantity > 0)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Text('×$quantity', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          IconButton(
            tooltip: 'Agregar',
            onPressed: onAdd,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline, size: 19, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _CurrentItemsPanel extends StatelessWidget {
  final List<SaleItemRecord> items;
  final Map<String, int> quantities;
  final ValueChanged<String> onIncrement;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onRemove;

  const _CurrentItemsPanel({
    required this.items,
    required this.quantities,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
          child: Row(
            children: [
              const Expanded(child: Text('Productos de la venta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              Text('${items.length}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(18), child: Text('Agrega productos para corregir la venta.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.textMuted))))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    if (item.isElectronicBalance) {
                      return _LockedElectronicItem(item: item);
                    }
                    final quantity = quantities[item.productId] ?? 0;
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                          IconButton(tooltip: 'Quitar uno', onPressed: () => onDecrement(item.productId), visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_circle_outline, size: 18)),
                          Text('$quantity', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          IconButton(tooltip: 'Agregar uno', onPressed: () => onIncrement(item.productId), visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary)),
                          IconButton(tooltip: 'Eliminar producto', onPressed: () => onRemove(item.productId), visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.dangerRed)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _LockedElectronicItem extends StatelessWidget {
  final SaleItemRecord item;
  const _LockedElectronicItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android_outlined, size: 17, color: AppColors.primary),
          const SizedBox(width: 7),
          Expanded(child: Text('${item.productName} · ×${item.quantity}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10))),
          const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
