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

  static Future<List<SaleItemRecord>?> show(BuildContext context, {required SaleRecord sale}) {
    return showDialog<List<SaleItemRecord>>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) => Dialog(backgroundColor: Colors.transparent, child: EditCreditSaleDialog(sale: sale)),
    );
  }

  @override State<EditCreditSaleDialog> createState() => _EditCreditSaleDialogState();
}

class _EditCreditSaleDialogState extends State<EditCreditSaleDialog> {
  final TextEditingController _searchController = TextEditingController();
  late final Map<String, int> _quantities;
  late final Set<String> _touchedIds;
  String _query = '';

  bool get _hasElectronicItems => widget.sale.items.any((item) => item.isElectronicBalance);

  @override
  void initState() {
    super.initState();
    _quantities = {for (final item in widget.sale.items) if (!item.isElectronicBalance) item.productId: item.quantity};
    _touchedIds = {..._quantities.keys};
  }

  @override void dispose() { _searchController.dispose(); super.dispose(); }

  List<Product> _filteredProducts(ProductProvider provider) {
    final query = _query.trim().toLowerCase();
    final products = provider.products.where((product) => query.isEmpty || product.name.toLowerCase().contains(query) || product.barcode.toLowerCase().contains(query)).toList();
    products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
    for (final id in _touchedIds) {
      final product = provider.findById(id);
      if (product != null && seen.add(product.id)) result.add(product);
    }
    return result;
  }

  bool _hasChanges() {
    final original = {for (final item in widget.sale.items) if (!item.isElectronicBalance) item.productId: item.quantity};
    final ids = {...original.keys, ..._quantities.keys};
    for (final id in ids) {
      if ((original[id] ?? 0) != (_quantities[id] ?? 0)) return true;
    }
    return false;
  }

  List<SaleItemRecord> _buildItems(ProductProvider provider) {
    final items = <SaleItemRecord>[];
    for (final oldItem in widget.sale.items) {
      if (oldItem.isElectronicBalance) { items.add(oldItem); continue; }
      final quantity = _quantities[oldItem.productId] ?? 0;
      if (quantity <= 0) continue;
      final product = provider.findById(oldItem.productId);
      if (product == null) continue;
      items.add(_record(product, quantity));
    }
    for (final entry in _quantities.entries) {
      if (widget.sale.items.any((item) => item.productId == entry.key) || entry.value <= 0) continue;
      final product = provider.findById(entry.key);
      if (product != null) items.add(_record(product, entry.value));
    }
    return items;
  }

  SaleItemRecord _record(Product product, int quantity) {
    final lineSubtotal = product.price * quantity;
    return SaleItemRecord(productId: product.id, productName: product.name, unit: product.unit, barcode: product.barcode, cost: product.cost, unitPrice: product.price, quantity: quantity, lineSubtotal: lineSubtotal, discount: 0, lineTotal: lineSubtotal, imageData: product.imageData);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final products = _filteredProducts(provider);
    final currentProducts = _currentProducts(provider);
    final selectedCount = _quantities.values.fold<int>(0, (sum, value) => sum + value);
    final removals = currentProducts.where((product) => (_quantities[product.id] ?? 0) == 0).length;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 14, 14), child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_note_outlined, color: AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Editar venta fiada', style: AppTextStyles.sectionTitle), const SizedBox(height: 2), Text('Ticket #${widget.sale.ticketNumber} · ${widget.sale.clientName}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))])),
            IconButton(tooltip: 'Cerrar', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
          ])),
          const Divider(height: 1, color: AppColors.border),
          if (_hasElectronicItems) Container(margin: const EdgeInsets.fromLTRB(16, 10, 16, 0), padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppColors.warningOrange.withAlpha(12), borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.warningOrange.withAlpha(35))), child: const Row(children: [Icon(Icons.info_outline, size: 17, color: AppColors.warningOrange), SizedBox(width: 8), Expanded(child: Text('Las recargas electrónicas se conservan sin cambios. Aquí puedes corregir los productos físicos.', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)))])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), child: TextField(controller: _searchController, onChanged: (value) => setState(() => _query = value), decoration: InputDecoration(hintText: 'Buscar producto para agregar...', prefixIcon: const Icon(Icons.search, size: 19), suffixIcon: _query.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() => _query = ''); }, icon: const Icon(Icons.clear, size: 17))))),
          Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _ProductListPanel(title: 'Agregar productos', count: products.length, emptyText: 'No hay productos que coincidan con la búsqueda.', products: products, quantities: _quantities, onAdd: (product) => setState(() { _touchedIds.add(product.id); _quantities[product.id] = (_quantities[product.id] ?? 0) + 1; }), isSelectionPanel: true)),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: _CurrentProductsPanel(products: currentProducts, quantities: _quantities, electronicItems: widget.sale.items.where((item) => item.isElectronicBalance).toList(), removals: removals, onIncrement: (id) => setState(() { _touchedIds.add(id); _quantities[id] = (_quantities[id] ?? 0) + 1; }), onDecrement: (id) => setState(() { _touchedIds.add(id); _quantities[id] = (_quantities[id] ?? 0) - 1; }), onRemove: (id) => setState(() { _touchedIds.add(id); _quantities[id] = 0; }))),
          ])),
          Container(padding: const EdgeInsets.fromLTRB(16, 10, 16, 12), decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))), child: Row(children: [Text('$selectedCount unidades', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)), if (removals > 0) ...[const SizedBox(width: 9), Text('$removals se eliminará(n)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.dangerRed))], const Spacer(), TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')), const SizedBox(width: 8), FilledButton.icon(onPressed: _hasChanges() ? () => Navigator.of(context).pop(_buildItems(provider)) : null, icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Revisar cambios'))])),
        ]),
      ),
    );
  }
}

class _ProductListPanel extends StatelessWidget {
  final String title; final int count; final String emptyText; final List<Product> products; final Map<String, int> quantities; final ValueChanged<Product> onAdd; final bool isSelectionPanel;
  const _ProductListPanel({required this.title, required this.count, required this.emptyText, required this.products, required this.quantities, required this.onAdd, required this.isSelectionPanel});
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),), Text('$count', style: const TextStyle(fontSize: 10, color: AppColors.textMuted))])),
    Expanded(child: products.isEmpty ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(emptyText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)))) : ListView.separated(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), itemCount: products.length, separatorBuilder: (_, __) => const SizedBox(height: 7), itemBuilder: (_, index) { final product = products[index]; return _EditProductCard(product: product, quantity: quantities[product.id] ?? 0, mode: _EditCardMode.add, onAdd: () => onAdd(product)); }))
  ]);
}

enum _EditCardMode { add, edit }

class _CurrentProductsPanel extends StatelessWidget {
  final List<Product> products; final Map<String, int> quantities; final List<SaleItemRecord> electronicItems; final int removals; final ValueChanged<String> onIncrement; final ValueChanged<String> onDecrement; final ValueChanged<String> onRemove;
  const _CurrentProductsPanel({required this.products, required this.quantities, required this.electronicItems, required this.removals, required this.onIncrement, required this.onDecrement, required this.onRemove});
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: Row(children: [const Expanded(child: Text('Productos de la venta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))), Text('${products.length + electronicItems.length}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted))])),
    Expanded(child: ListView.separated(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), itemCount: products.length + electronicItems.length, separatorBuilder: (_, __) => const SizedBox(height: 7), itemBuilder: (_, index) {
      if (index >= products.length) return _LockedElectronicCard(item: electronicItems[index - products.length]);
      final product = products[index];
      final quantity = quantities[product.id] ?? 0;
      return _EditProductCard(product: product, quantity: quantity, mode: _EditCardMode.edit, onIncrement: () => onIncrement(product.id), onDecrement: () => onDecrement(product.id), onRemove: () => onRemove(product.id));
    }))
  ]);
}

class _EditProductCard extends StatelessWidget {
  final Product product; final int quantity; final _EditCardMode mode; final VoidCallback? onAdd; final VoidCallback? onIncrement; final VoidCallback? onDecrement; final VoidCallback? onRemove;
  const _EditProductCard({required this.product, required this.quantity, required this.mode, this.onAdd, this.onIncrement, this.onDecrement, this.onRemove});
  @override Widget build(BuildContext context) {
    final zero = quantity <= 0 && mode == _EditCardMode.edit;
    final active = quantity > 0;
    final border = zero ? AppColors.dangerRed : active ? AppColors.primary : AppColors.border;
    final background = zero ? AppColors.dangerRed.withAlpha(8) : AppColors.inputBackground;
    return AnimatedContainer(duration: const Duration(milliseconds: 160), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(11), border: Border.all(color: border, width: zero || active ? 1.4 : 1)), child: Row(children: [
      _Thumbnail(imageData: product.imageData),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text('${product.unit} · \$${product.price.toStringAsFixed(2)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)), if (zero) ...[const SizedBox(height: 3), const Text('Se eliminará de la venta', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.dangerRed))]])),
      if (mode == _EditCardMode.add) ...[
        if (active) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5), decoration: BoxDecoration(color: AppColors.primary.withAlpha(15), borderRadius: BorderRadius.circular(7)), child: Text('×$quantity', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary))),
        const SizedBox(width: 5),
        IconButton(tooltip: 'Agregar', onPressed: onAdd, visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 21)),
      ] else ...[
        _RoundAction(icon: Icons.remove_rounded, color: zero ? AppColors.dangerRed : AppColors.textSecondary, onTap: onDecrement),
        AnimatedContainer(duration: const Duration(milliseconds: 140), width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: zero ? AppColors.dangerRed.withAlpha(16) : AppColors.primary.withAlpha(14), shape: BoxShape.circle, border: Border.all(color: zero ? AppColors.dangerRed : AppColors.primary.withAlpha(90))), child: Text('$quantity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: zero ? AppColors.dangerRed : AppColors.primary))),
        _RoundAction(icon: Icons.add_rounded, color: AppColors.primary, onTap: onIncrement),
        IconButton(tooltip: 'Marcar para eliminar', onPressed: onRemove, visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.dangerRed)),
      ],
    ]));
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback? onTap;
  const _RoundAction({required this.icon, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => IconButton(onPressed: onTap, visualDensity: VisualDensity.compact, tooltip: icon == Icons.add_rounded ? 'Agregar uno' : 'Quitar uno', icon: Icon(icon, size: 18, color: color));
}

class _LockedElectronicCard extends StatelessWidget {
  final SaleItemRecord item;
  const _LockedElectronicCard({required this.item});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primary.withAlpha(12), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.phone_android_outlined, color: AppColors.primary)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), Text('${item.unit} · \$${item.unitPrice.toStringAsFixed(2)} · ×${item.quantity}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary))])), const Icon(Icons.lock_outline, size: 15, color: AppColors.textMuted)]));
}

class _Thumbnail extends StatelessWidget {
  final String imageData;
  const _Thumbnail({required this.imageData});
  @override Widget build(BuildContext context) {
    if (imageData.trim().isNotEmpty) {
      try { return Container(width: 54, height: 54, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)), child: Image.memory(base64Decode(imageData.contains(',') ? imageData.split(',').last : imageData), fit: BoxFit.cover)); } catch (_) {}
    }
    return Container(width: 54, height: 54, decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)), child: const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 24));
  }
}
