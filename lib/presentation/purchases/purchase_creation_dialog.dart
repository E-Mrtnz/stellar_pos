import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';
import 'package:stellar_pos/core/providers/purchases_provider.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class PurchaseCreationDialog extends StatefulWidget {
  const PurchaseCreationDialog({super.key});

  static Future<bool?> show(BuildContext context) => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PurchaseCreationDialog(),
      );

  @override
  State<PurchaseCreationDialog> createState() => _PurchaseCreationDialogState();
}

class _PurchaseCreationDialogState extends State<PurchaseCreationDialog> {
  final _invoiceController = TextEditingController();
  final _searchController = TextEditingController();
  final _barcodeController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _distributor;
  final List<_DraftPurchaseItem> _items = [];
  final Set<String> _skipCostPrompt = <String>{};
  bool _saving = false;

  @override
  void dispose() {
    _invoiceController.dispose();
    _searchController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
  String _dateText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  List<Product> _filteredProducts(ProductProvider provider) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return provider.products;
    return provider.products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.brand.toLowerCase().contains(query);
    }).toList();
  }

  double get _total => _items.fold(0, (sum, item) => sum + item.totalCost);
  int get _received => _items.fold(0, (sum, item) => sum + item.totalQuantity);
  int get _bonuses => _items.fold(0, (sum, item) => sum + item.bonusQuantity);

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final filtered = _filteredProducts(products);
    final distributors = context.watch<ProvidersProvider>().distributors;

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 830),
        child: Column(
          children: [
            _header(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: _generalInfo(distributors),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    Expanded(flex: 5, child: _picker(filtered)),
                    const SizedBox(width: 14),
                    Expanded(flex: 6, child: _purchaseList()),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
        child: Row(
          children: [
            const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 25),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nueva compra', style: AppTextStyles.sectionTitle),
                  SizedBox(height: 2),
                  Text('Registra productos, bonificaciones y costos.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(onPressed: _saving ? null : () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
          ],
        ),
      );

  Widget _generalInfo(List<String> distributors) => Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _distributor,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Distribuidora', prefixIcon: Icon(Icons.storefront_outlined), border: OutlineInputBorder(), isDense: true),
              items: distributors.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: _saving ? null : (value) => setState(() => _distributor = value),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _invoiceController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'N.º de factura', prefixIcon: Icon(Icons.receipt_long_outlined), border: OutlineInputBorder(), isDense: true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: _saving ? null : _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha', prefixIcon: Icon(Icons.calendar_today_outlined), border: OutlineInputBorder(), isDense: true),
                child: Text(_dateText(_date)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.payments_outlined, size: 18, color: AppColors.successGreen), SizedBox(width: 7), Text('Contado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
          ),
        ],
      );

  Widget _picker(List<Product> products) => Container(
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Agregar productos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                  Text('${products.length} disponibles', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(hintText: 'Buscar producto...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(onPressed: _showBarcodeEntry, tooltip: 'Escanear código', icon: const Icon(Icons.qr_code_scanner_outlined)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: products.isEmpty
                  ? const Center(child: Text('No hay productos registrados.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 175, mainAxisExtent: 132, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: products.length,
                      itemBuilder: (_, index) => _productCard(products[index]),
                    ),
            ),
          ],
        ),
      );

  Widget _productCard(Product product) {
    final query = _searchController.text.trim().toLowerCase();
    final matches = query.isEmpty ||
        product.name.toLowerCase().contains(query) ||
        product.barcode.toLowerCase().contains(query) ||
        product.brand.toLowerCase().contains(query);
    if (!matches) return const SizedBox.shrink();
    final image = _decode(product.imageData);
    return InkWell(
      onTap: _saving ? null : () => _openItemEditor(product),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: image == null ? const Icon(Icons.inventory_2_outlined, size: 32, color: AppColors.textMuted) : Image.memory(image, fit: BoxFit.contain))),
            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Costo ${_money(product.cost)}  •  Stock ${product.stock}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _purchaseList() => Container(
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(child: Text('Productos de la compra', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                  if (_items.isNotEmpty) Text('$_received recibidas  •  $_bonuses bonificadas', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_shopping_cart_outlined, size: 44, color: AppColors.textMuted), SizedBox(height: 8), Text('Selecciona productos de la izquierda', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)), SizedBox(height: 3), Text('También puedes escanear un código.', style: TextStyle(fontSize: 10, color: AppColors.textMuted))]))
                  : ListView.separated(padding: const EdgeInsets.all(10), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 7), itemBuilder: (_, index) => _itemRow(index)),
            ),
          ],
        ),
      );

  Widget _itemRow(int index) {
    final item = _items[index];
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 7, 9),
      decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Row(
            children: [
              _image(item.product.imageData),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text('Costo ${_money(item.unitCost)}  •  Venta ${_money(item.salePrice)}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary))])),
              IconButton(tooltip: 'Editar', onPressed: _saving ? null : () => _openItemEditor(item.product, existingIndex: index), icon: const Icon(Icons.edit_outlined, size: 18)),
              IconButton(tooltip: 'Eliminar', onPressed: _saving ? null : () => setState(() => _items.removeAt(index)), icon: const Icon(Icons.delete_outline, size: 18)),
            ],
          ),
          const SizedBox(height: 7),
          Row(children: [_stat('Compradas', '${item.purchasedQuantity}'), _stat('Bonificadas', '${item.bonusQuantity}', color: AppColors.successGreen), _stat('Recibidas', '${item.totalQuantity}'), _stat('Costo', _money(item.unitCost)), _stat('Importe', _money(item.totalCost), flex: 2)]),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color, int flex = 1}) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textMuted)), const SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))]),
        ),
      );

  Widget _footer() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 11, 20, 13),
        child: Row(
          children: [
            _stat('Unidades recibidas', '$_received'),
            const SizedBox(width: 14),
            _stat('Bonificaciones', '$_bonuses', color: AppColors.successGreen),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('TOTAL PAGADO', style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700)), Text(_money(_total), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.primary))]),
            const SizedBox(width: 16),
            FilledButton.icon(onPressed: _saving || _items.isEmpty ? null : _save, icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check), label: Text(_saving ? 'Guardando...' : 'Guardar compra')),
          ],
        ),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date);
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
  }

  Future<void> _showBarcodeEntry() async {
    _barcodeController.clear();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Escanear producto'),
        content: TextField(controller: _barcodeController, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Código de barras', hintText: 'Escanea o escribe el código', prefixIcon: Icon(Icons.qr_code_scanner_outlined)), onSubmitted: (text) => Navigator.pop(dialogContext, text.trim())),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialogContext, _barcodeController.text.trim()), child: const Text('Buscar'))],
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    final product = context.read<ProductProvider>().findByBarcode(value);
    if (product == null) {
      _error('No se encontró un producto con ese código.');
      return;
    }
    await _openItemEditor(product);
  }

  Future<void> _openItemEditor(Product product, {int? existingIndex}) async {
    final existing = existingIndex == null ? null : _items[existingIndex];
    final result = await showDialog<_DraftPurchaseItem>(context: context, builder: (_) => _PurchaseItemEditor(product: product, existing: existing));
    if (result == null || !mounted) return;
    setState(() {
      if (existingIndex != null) {
        _items[existingIndex] = result;
      } else {
        final index = _items.indexWhere((item) => item.product.id == product.id);
        if (index >= 0) {
          _items[index] = result;
        } else {
          _items.add(result);
        }
      }
    });
  }

  Future<void> _save() async {
    if (_distributor == null || _distributor!.trim().isEmpty) {
      _error('Selecciona una distribuidora.');
      return;
    }
    if (_items.isEmpty) {
      _error('Agrega al menos un producto.');
      return;
    }
    setState(() => _saving = true);
    try {
      final productProvider = context.read<ProductProvider>();
      for (final item in _items) {
        final current = productProvider.findById(item.product.id);
        if (current == null || _skipCostPrompt.contains(item.product.id)) continue;
        if ((current.cost - item.unitCost).abs() <= 0.0001) continue;
        final decision = await showDialog<_CostDecision>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _CostChangeDialog(product: current, newCost: item.unitCost),
        );
        if (!mounted || decision == null) {
          setState(() => _saving = false);
          return;
        }
        if (decision.updateCost) {
          productProvider.updateProduct(current.copyWith(cost: item.unitCost));
        }
        if (decision.skipFuture) _skipCostPrompt.add(item.product.id);
      }

      for (final item in _items) {
        final current = productProvider.findById(item.product.id);
        if (current == null) continue;
        final updated = current.copyWith(
          stock: current.stock + item.totalQuantity,
          price: item.salePrice,
        );
        productProvider.updateProduct(updated);
      }

      final purchase = PurchaseRecord(
        id: IdGenerator.newId(),
        invoiceNumber: _invoiceController.text.trim(),
        distributorName: _distributor!.trim(),
        arrivalAt: _date,
        paymentMethod: 'Contado',
        items: _items.map((item) => PurchaseItemRecord(
          productId: item.product.id,
          productName: item.product.name,
          unit: item.product.unit,
          barcode: item.product.barcode,
          imageData: item.product.imageData,
          unitCost: item.unitCost,
          quantity: item.purchasedQuantity,
          bonusQuantity: item.bonusQuantity,
          totalQuantity: item.totalQuantity,
          salePrice: item.salePrice,
          discount: item.discount,
          total: item.totalCost,
          effectiveUnitCost: item.effectiveUnitCost,
        )).toList(),
        subtotal: _total,
        discount: _items.fold(0, (sum, item) => sum + item.discount),
        total: _total,
      );
      context.read<PurchasesProvider>().addPurchase(purchase);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _error('No se pudo guardar la compra: $error');
    }
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Widget _image(String data) {
    final bytes = _decode(data);
    return Container(width: 45, height: 45, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: bytes == null ? const Icon(Icons.image_outlined, size: 20, color: AppColors.textMuted) : Image.memory(bytes, fit: BoxFit.contain));
  }

  Uint8List? _decode(String value) {
    if (value.trim().isEmpty) return null;
    try {
      return base64Decode(value.contains(',') ? value.split(',').last : value);
    } catch (_) {
      return null;
    }
  }
}

class _DraftPurchaseItem {
  final Product product;
  final int purchasedQuantity;
  final int bonusQuantity;
  final double unitCost;
  final double salePrice;
  final double discount;

  const _DraftPurchaseItem({required this.product, required this.purchasedQuantity, required this.bonusQuantity, required this.unitCost, required this.salePrice, required this.discount});

  int get totalQuantity => purchasedQuantity + bonusQuantity;
  double get totalCost => (purchasedQuantity * unitCost) - discount;
  double get effectiveUnitCost => totalQuantity <= 0 ? 0 : totalCost / totalQuantity;
}

class _PurchaseItemEditor extends StatefulWidget {
  final Product product;
  final _DraftPurchaseItem? existing;
  const _PurchaseItemEditor({required this.product, this.existing});
  @override
  State<_PurchaseItemEditor> createState() => _PurchaseItemEditorState();
}

class _PurchaseItemEditorState extends State<_PurchaseItemEditor> {
  late final TextEditingController _quantity;
  late final TextEditingController _bonus;
  late final TextEditingController _cost;
  late final TextEditingController _salePrice;
  late final TextEditingController _discount;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _quantity = TextEditingController(text: '${item?.purchasedQuantity ?? 1}');
    _bonus = TextEditingController(text: '${item?.bonusQuantity ?? 0}');
    _cost = TextEditingController(text: (item?.unitCost ?? widget.product.cost).toStringAsFixed(2));
    _salePrice = TextEditingController(text: (item?.salePrice ?? widget.product.price).toStringAsFixed(2));
    _discount = TextEditingController(text: (item?.discount ?? 0).toStringAsFixed(2));
  }

  @override
  void dispose() {
    _quantity.dispose();
    _bonus.dispose();
    _cost.dispose();
    _salePrice.dispose();
    _discount.dispose();
    super.dispose();
  }

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  double _double(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final quantity = _int(_quantity).clamp(0, 1 << 30).toInt();
    final bonus = _int(_bonus).clamp(0, 1 << 30).toInt();
    final cost = _double(_cost).clamp(0, double.infinity).toDouble();
    final discount = _double(_discount).clamp(0, double.infinity).toDouble();
    final double total = quantity * cost - discount;
    final received = quantity + bonus;
    final double effective = received == 0 ? 0.0 : total / received;
    return AlertDialog(
      title: Text(widget.product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [Expanded(child: _field(_quantity, 'Compradas', Icons.shopping_cart_outlined, decimal: false)), const SizedBox(width: 8), Expanded(child: _field(_bonus, 'Bonificadas', Icons.card_giftcard_outlined, decimal: false)), const SizedBox(width: 8), Expanded(child: _field(_cost, 'Costo unitario', Icons.attach_money))]),
            const SizedBox(height: 9),
            Row(children: [Expanded(child: _field(_salePrice, 'Precio de venta', Icons.sell_outlined)), const SizedBox(width: 8), Expanded(child: _field(_discount, 'Descuento', Icons.discount_outlined))]),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Row(children: [_summary('Compradas', '$quantity'), _summary('Bonificadas', '$bonus', color: AppColors.successGreen), _summary('Recibidas', '$received'), _summary('Pagado', _money(total), color: AppColors.primary), _summary('Costo efectivo', _money(effective))])),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton.icon(onPressed: quantity <= 0 || cost < 0 || total < 0 ? null : () => Navigator.pop(context, _DraftPurchaseItem(product: widget.product, purchasedQuantity: quantity, bonusQuantity: bonus, unitCost: cost, salePrice: _double(_salePrice), discount: discount)), icon: const Icon(Icons.check), label: Text(widget.existing == null ? 'Agregar' : 'Guardar cambios'))],
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {bool decimal = true}) => TextField(controller: c, keyboardType: TextInputType.numberWithOptions(decimal: decimal), decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), border: const OutlineInputBorder(), isDense: true), onChanged: (_) => setState(() {}));
  Widget _summary(String label, String value, {Color? color}) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textMuted)), const SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))]));
}

class _CostDecision {
  final bool updateCost;
  final bool skipFuture;
  const _CostDecision({required this.updateCost, required this.skipFuture});
}

class _CostChangeDialog extends StatefulWidget {
  final Product product;
  final double newCost;
  const _CostChangeDialog({required this.product, required this.newCost});
  @override
  State<_CostChangeDialog> createState() => _CostChangeDialogState();
}

class _CostChangeDialogState extends State<_CostChangeDialog> {
  bool _skipFuture = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Actualizar costos'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('El costo de este producto es diferente al registrado. Elige cómo actualizarlo.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.product.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)), const SizedBox(height: 12), Row(children: [_cost('Actual', widget.product.cost), const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Icon(Icons.arrow_forward_outlined, color: AppColors.textMuted)), _cost('Nuevo', widget.newCost, color: AppColors.successGreen)])]),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(value: _skipFuture, onChanged: (value) => setState(() => _skipFuture = value ?? false), contentPadding: EdgeInsets.zero, dense: true, title: const Text('No volver a preguntarme para este producto', style: TextStyle(fontSize: 11)), subtitle: const Text('Se aplica durante este registro de compra.', style: TextStyle(fontSize: 9))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, _CostDecision(updateCost: false, skipFuture: _skipFuture)), child: const Text('Saltar')),
          FilledButton(onPressed: () => Navigator.pop(context, _CostDecision(updateCost: true, skipFuture: _skipFuture)), child: Text('Registrar \$${widget.newCost.toStringAsFixed(2)} como costo')),
        ],
      );

  Widget _cost(String label, double value, {Color? color}) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)), const SizedBox(height: 2), Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color))]));
}
