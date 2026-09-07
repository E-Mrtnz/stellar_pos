import 'dart:convert';

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
  late final Map<String, int> _originalQuantities;
  late final Map<String, int> _quantities;
  late final Map<String, int> _addedQuantities;
  String _query = '';

  bool get _hasElectronicItems =>
      widget.sale.items.any((item) => item.isElectronicBalance);

  @override
  void initState() {
    super.initState();
    _originalQuantities = {
      for (final item in widget.sale.items)
        if (!item.isElectronicBalance) item.productId: item.quantity,
    };
    _quantities = Map<String, int>.from(_originalQuantities);
    _addedQuantities = {};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filteredProducts(ProductProvider provider) {
    final query = _query.trim().toLowerCase();
    final products = provider.products
        .where(
          (product) =>
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              product.barcode.toLowerCase().contains(query),
        )
        .toList();
    products.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return products;
  }

  List<Product> _currentProducts(ProductProvider provider) {
    final result = <Product>[];
    final seen = <String>{};

    for (final item in widget.sale.items) {
      if (item.isElectronicBalance) continue;
      final product = provider.findById(item.productId);
      if (product != null && seen.add(product.id)) result.add(product);
    }

    for (final id in _addedQuantities.keys) {
      if ((_quantities[id] ?? 0) <= 0) continue;
      final product = provider.findById(id);
      if (product != null && seen.add(product.id)) result.add(product);
    }

    return result;
  }

  bool _hasChanges() {
    final ids = {..._originalQuantities.keys, ..._quantities.keys};
    for (final id in ids) {
      if ((_originalQuantities[id] ?? 0) != (_quantities[id] ?? 0)) {
        return true;
      }
    }
    return false;
  }

  void _addFromCatalog(Product product) {
    final current = _quantities[product.id] ?? 0;
    final original = _originalQuantities[product.id] ?? 0;
    _quantities[product.id] = current + 1;

    if (current >= original) {
      _addedQuantities[product.id] = (_addedQuantities[product.id] ?? 0) + 1;
    }
    setState(() {});
  }

  void _removeAdded(String id) {
    final added = _addedQuantities[id] ?? 0;
    if (added <= 0) return;

    final current = _quantities[id] ?? 0;
    _quantities[id] = (current - added).clamp(0, double.infinity).toInt();
    _addedQuantities.remove(id);
    setState(() {});
  }

  void _increment(String id) {
    final current = _quantities[id] ?? 0;
    final original = _originalQuantities[id] ?? 0;
    _quantities[id] = current + 1;

    if (current >= original) {
      _addedQuantities[id] = (_addedQuantities[id] ?? 0) + 1;
    }
    setState(() {});
  }

  void _decrement(String id) {
    final current = _quantities[id] ?? 0;
    if (current <= 0) return;

    _quantities[id] = current - 1;
    final added = _addedQuantities[id] ?? 0;
    if (added > 0) {
      if (added == 1) {
        _addedQuantities.remove(id);
      } else {
        _addedQuantities[id] = added - 1;
      }
    }
    setState(() {});
  }

  void _markForRemoval(String id) {
    _quantities[id] = 0;
    _addedQuantities.remove(id);
    setState(() {});
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
      items.add(_record(product, quantity));
    }

    for (final entry in _quantities.entries) {
      if (_originalQuantities.containsKey(entry.key) || entry.value <= 0) {
        continue;
      }
      final product = provider.findById(entry.key);
      if (product != null) items.add(_record(product, entry.value));
    }

    return items;
  }

  SaleItemRecord _record(Product product, int quantity) {
    final lineSubtotal = product.price * quantity;
    return SaleItemRecord(
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
    );
  }

  Future<void> _reviewChanges(ProductProvider provider) async {
    if (!_hasChanges()) return;

    final items = _buildItems(provider);
    if (items.isEmpty) return;

    final removedCount = _originalQuantities.entries
        .where((entry) => entry.value > 0 && (_quantities[entry.key] ?? 0) == 0)
        .length;
    final addedUnits = _addedQuantities.values.fold<int>(0, (sum, value) => sum + value);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (dialogContext) => _ConfirmDialog(
        title: 'Confirmar cambios',
        icon: Icons.edit_note_outlined,
        message:
            'La venta #${widget.sale.ticketNumber} se actualizará con los cambios seleccionados.',
        details: [
          if (addedUnits > 0) '$addedUnits unidad(es) agregada(s).',
          if (removedCount > 0) '$removedCount producto(s) se eliminará(n).',
          'Total anterior: \$${widget.sale.total.toStringAsFixed(2)}',
          '¿Deseas aplicar estos cambios?',
        ],
        confirmLabel: 'Confirmar',
        onConfirm: () => Navigator.pop(dialogContext, true),
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(items);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final products = _filteredProducts(provider);
    final currentProducts = _currentProducts(provider);
    final selectedCount = _quantities.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final removals = currentProducts
        .where((product) => (_quantities[product.id] ?? 0) == 0)
        .length;
    final addedUnits = _addedQuantities.values.fold<int>(0, (sum, value) => sum + value);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
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
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.all(9),
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
                        'Las recargas electrónicas se conservan sin cambios. Aquí puedes corregir los productos físicos.',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Buscar producto para agregar...',
                  prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
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
                    child: _ProductListPanel(
                      title: 'Agregar productos',
                      count: products.length,
                      emptyText: 'No hay productos que coincidan con la búsqueda.',
                      products: products,
                      quantities: _quantities,
                      addedQuantities: _addedQuantities,
                      onAdd: _addFromCatalog,
                      onRemoveAdded: _removeAdded,
                    ),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.border),
                  Expanded(
                    child: _CurrentProductsPanel(
                      products: currentProducts,
                      quantities: _quantities,
                      electronicItems: widget.sale.items
                          .where((item) => item.isElectronicBalance)
                          .toList(),
                      removals: removals,
                      onIncrement: _increment,
                      onDecrement: _decrement,
                      onRemove: _markForRemoval,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text(
                    '$selectedCount unidades',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  if (addedUnits > 0) ...[
                    const SizedBox(width: 9),
                    Text(
                      '$addedUnits agregada(s)',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                  if (removals > 0) ...[
                    const SizedBox(width: 9),
                    Text(
                      '$removals se eliminará(n)',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dangerRed,
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _hasChanges() ? () => _reviewChanges(provider) : null,
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

class _ProductListPanel extends StatelessWidget {
  final String title;
  final int count;
  final String emptyText;
  final List<Product> products;
  final Map<String, int> quantities;
  final Map<String, int> addedQuantities;
  final ValueChanged<Product> onAdd;
  final ValueChanged<String> onRemoveAdded;

  const _ProductListPanel({
    required this.title,
    required this.count,
    required this.emptyText,
    required this.products,
    required this.quantities,
    required this.addedQuantities,
    required this.onAdd,
    required this.onRemoveAdded,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '$count',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        emptyText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (_, index) {
                      final product = products[index];
                      final added = addedQuantities[product.id] ?? 0;
                      final quantity = quantities[product.id] ?? 0;
                      return _EditProductCard(
                        product: product,
                        quantity: quantity,
                        mode: _EditCardMode.add,
                        addedQuantity: added,
                        onAdd: () => onAdd(product),
                        onRemoveAdded: added > 0 ? () => onRemoveAdded(product.id) : null,
                      );
                    },
                  ),
          ),
        ],
      );
}

enum _EditCardMode { add, edit }

class _CurrentProductsPanel extends StatelessWidget {
  final List<Product> products;
  final Map<String, int> quantities;
  final List<SaleItemRecord> electronicItems;
  final int removals;
  final ValueChanged<String> onIncrement;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onRemove;

  const _CurrentProductsPanel({
    required this.products,
    required this.quantities,
    required this.electronicItems,
    required this.removals,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Productos de la venta',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${products.length + electronicItems.length}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: products.length + electronicItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (_, index) {
                if (index >= products.length) {
                  return _LockedElectronicCard(
                    item: electronicItems[index - products.length],
                  );
                }
                final product = products[index];
                final quantity = quantities[product.id] ?? 0;
                return _EditProductCard(
                  product: product,
                  quantity: quantity,
                  mode: _EditCardMode.edit,
                  onIncrement: () => onIncrement(product.id),
                  onDecrement: () => onDecrement(product.id),
                  onRemove: () => onRemove(product.id),
                );
              },
            ),
          ),
        ],
      );
}

class _EditProductCard extends StatelessWidget {
  final Product product;
  final int quantity;
  final _EditCardMode mode;
  final int addedQuantity;
  final VoidCallback? onAdd;
  final VoidCallback? onRemoveAdded;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onRemove;

  const _EditProductCard({
    required this.product,
    required this.quantity,
    required this.mode,
    this.addedQuantity = 0,
    this.onAdd,
    this.onRemoveAdded,
    this.onIncrement,
    this.onDecrement,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final zero = quantity == 0 && mode == _EditCardMode.edit;
    final active = quantity > 0;
    final border = zero
        ? AppColors.dangerRed
        : active
            ? AppColors.primary.withAlpha(110)
            : AppColors.border;
    final background = zero ? AppColors.dangerRed.withAlpha(8) : AppColors.inputBackground;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: border, width: zero || active ? 1.3 : 1),
      ),
      child: Row(
        children: [
          _Thumbnail(imageData: product.imageData),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.unit} · \$${product.price.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                ),
                if (zero) ...[
                  const SizedBox(height: 3),
                  const Text(
                    'Se eliminará de la venta',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dangerRed,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (mode == _EditCardMode.add) ...[
            if (addedQuantity > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '×$addedQuantity',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            if (addedQuantity > 0) ...[
              const SizedBox(width: 3),
              IconButton(
                tooltip: 'Quitar lo agregado',
                onPressed: onRemoveAdded,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: AppColors.dangerRed,
                  size: 20,
                ),
              ),
            ],
            IconButton(
              tooltip: 'Agregar',
              onPressed: onAdd,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.primary,
                size: 21,
              ),
            ),
          ] else ...[
            _RoundAction(
              icon: Icons.remove_rounded,
              color: zero ? AppColors.dangerRed : AppColors.textSecondary,
              onTap: onDecrement,
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: zero
                    ? AppColors.dangerRed.withAlpha(16)
                    : AppColors.primary.withAlpha(14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: zero
                      ? AppColors.dangerRed
                      : AppColors.primary.withAlpha(90),
                ),
              ),
              child: Text(
                '$quantity',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: zero ? AppColors.dangerRed : AppColors.primary,
                ),
              ),
            ),
            _RoundAction(
              icon: Icons.add_rounded,
              color: AppColors.primary,
              onTap: onIncrement,
            ),
            IconButton(
              tooltip: 'Marcar para eliminar',
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline,
                size: 19,
                color: AppColors.dangerRed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _RoundAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        tooltip: icon == Icons.add_rounded ? 'Agregar uno' : 'Quitar uno',
        icon: Icon(icon, size: 18, color: color),
      );
}

class _LockedElectronicCard extends StatelessWidget {
  final SaleItemRecord item;

  const _LockedElectronicCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.phone_android_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${item.unit} · \$${item.unitPrice.toStringAsFixed(2)} · ×${item.quantity}',
                    style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
          ],
        ),
      );
}

class _Thumbnail extends StatelessWidget {
  final String? imageData;

  const _Thumbnail({required this.imageData});

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    final value = imageData?.trim() ?? '';
    if (value.isNotEmpty) {
      try {
        bytes = base64Decode(
          value.contains(',') ? value.split(',').last : value,
        );
      } catch (_) {}
    }

    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: bytes == null
          ? const Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: AppColors.textMuted,
            )
          : Image.memory(bytes, fit: BoxFit.cover),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;
  final List<String> details;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmDialog({
    required this.title,
    required this.icon,
    required this.message,
    required this.details,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 21),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(title, style: AppTextStyles.sectionTitle),
                    ),
                    IconButton(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...details.map(
                  (detail) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 7),
                    FilledButton(
                      onPressed: onConfirm,
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
