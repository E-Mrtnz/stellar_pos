import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';
import 'package:stellar_pos/core/providers/purchases_provider.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';

class PurchaseCreationDialog extends StatefulWidget {
  final PurchaseRecord? purchase;
  const PurchaseCreationDialog({super.key, this.purchase});

  static Future<bool?> show(BuildContext context, {PurchaseRecord? purchase}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PurchaseCreationDialog(purchase: purchase),
    );
  }

  @override
  State<PurchaseCreationDialog> createState() => _PurchaseCreationDialogState();
}

class _PurchaseCreationDialogState extends State<PurchaseCreationDialog> {
  static const _scannerTimeout = Duration(milliseconds: 120);
  final _invoiceController = TextEditingController();
  final _searchController = TextEditingController();
  final _items = <_DraftPurchaseItem>[];
  String _scannerBuffer = '';
  DateTime? _lastScannerKey;
  DateTime _date = DateTime.now();
  String? _distributor;
  bool _saving = false;
  bool _dirty = false;

  bool get _editing => widget.purchase != null;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_barcodeKeyHandler);
    final purchase = widget.purchase;
    if (purchase != null) {
      _invoiceController.text = purchase.invoiceNumber;
      _distributor = purchase.distributorName;
      _date = purchase.arrivalAt;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDraft(purchase));
    }
  }

  void _loadDraft(PurchaseRecord purchase) {
    if (!mounted) return;
    final products = context.read<ProductProvider>();
    setState(() {
      _items
        ..clear()
        ..addAll(purchase.items.map((item) {
          final product = products.findById(item.productId) ?? Product(
            id: item.productId,
            name: item.productName,
            unit: item.unit,
            department: purchase.distributorName,
            cost: item.previousCost ?? item.unitCost,
            price: item.previousSalePrice ?? item.salePrice,
            stock: 0,
            minStock: 0,
            maxStock: 0,
            category: '',
            barcode: item.barcode,
            imageData: item.imageData,
          );
          return _DraftPurchaseItem(product: product, purchasedQuantity: item.quantity, bonusQuantity: item.bonusQuantity, unitCost: item.unitCost, salePrice: item.salePrice, discount: item.discount);
        }));
      _dirty = false;
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_barcodeKeyHandler);
    _invoiceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  KeyEventResult _barcodeKeyHandler(KeyEvent event) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true || event is! KeyDownEvent) return KeyEventResult.ignored;
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext?.findAncestorWidgetOfExactType<EditableText>() != null) return KeyEventResult.ignored;
    final enter = event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (enter) {
      final code = _scannerBuffer;
      _scannerBuffer = '';
      _lastScannerKey = null;
      if (code.length >= 6) {
        final product = context.read<ProductProvider>().findByBarcode(code);
        if (product != null) {
          FocusManager.instance.primaryFocus?.unfocus();
          _searchController.clear();
          _addProduct(product);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }
    final character = event.character;
    if (character == null || character.isEmpty || character.trim().isEmpty) return KeyEventResult.ignored;
    final now = DateTime.now();
    _scannerBuffer = _lastScannerKey == null || now.difference(_lastScannerKey!) > _scannerTimeout ? character : _scannerBuffer + character;
    _lastScannerKey = now;
    return KeyEventResult.handled;
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
  String _dateText(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  double get _total => _items.fold(0, (sum, item) => sum + item.totalCost);
  int get _received => _items.fold(0, (sum, item) => sum + item.received);
  int get _bonuses => _items.fold(0, (sum, item) => sum + item.bonusQuantity);

  List<Product> _visibleProducts(ProductProvider provider) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return provider.products;
    return provider.products.where((p) => p.name.toLowerCase().contains(query) || p.barcode.toLowerCase().contains(query) || p.brand.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final products = _visibleProducts(context.watch<ProductProvider>());
    final distributors = context.watch<ProvidersProvider>().distributors;
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 850),
        child: Column(children: [
          _header(),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(14), child: _purchaseInfo(distributors)),
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: Row(children: [Expanded(flex: 5, child: _productPicker(products)), const SizedBox(width: 14), Expanded(flex: 6, child: _purchaseItems())]))),
          const Divider(height: 1),
          _footer(),
        ]),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
    child: Row(children: [
      Icon(_editing ? Icons.edit_note_outlined : Icons.shopping_bag_outlined, color: AppColors.primary, size: 25),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_editing ? 'Modificar compra' : 'Nueva compra', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 2),
        Text(_editing ? 'Actualiza los datos de la compra${widget.purchase!.invoiceNumber.isEmpty ? '' : ' ${widget.purchase!.invoiceNumber}'}. Los cambios se aplicarán sobre el registro existente.' : 'Registra productos, bonificaciones y costos.', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      if (_editing) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withAlpha(55))), child: const Text('MODIFICACIÓN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.primary))),
      IconButton(onPressed: _saving ? null : _cancel, icon: const Icon(Icons.close)),
    ]),
  );

  Widget _purchaseInfo(List<String> distributors) => Row(children: [
    Expanded(flex: 2, child: DropdownButtonFormField<String>(initialValue: _distributor, isExpanded: true, decoration: const InputDecoration(labelText: 'Distribuidora', prefixIcon: Icon(Icons.storefront_outlined), border: OutlineInputBorder(), isDense: true), items: distributors.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(), onChanged: _saving ? null : (value) { setState(() { _distributor = value; _dirty = true; }); })),
    const SizedBox(width: 10),
    Expanded(child: TextField(controller: _invoiceController, enabled: !_saving, onChanged: (_) => _dirty = true, decoration: const InputDecoration(labelText: 'N.º de factura', prefixIcon: Icon(Icons.receipt_long_outlined), border: OutlineInputBorder(), isDense: true))),
    const SizedBox(width: 10),
    Expanded(child: InkWell(onTap: _saving ? null : _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'Fecha', prefixIcon: Icon(Icons.calendar_today_outlined), border: OutlineInputBorder(), isDense: true), child: Text(_dateText(_date))))),
    const SizedBox(width: 10),
    Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.payments_outlined, size: 18, color: AppColors.successGreen), SizedBox(width: 7), Text('Contado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))])),
  ]);

  Widget _productPicker(List<Product> products) => Container(
    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), child: Row(children: [const Expanded(child: Text('Agregar productos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))), Text('${products.length} disponibles', style: const TextStyle(fontSize: 10, color: AppColors.textMuted))])),
      Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: TextField(controller: _searchController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Buscar producto...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true))),
      const Divider(height: 1),
      Expanded(child: products.isEmpty ? const Center(child: Text('No hay productos registrados.')) : GridView.builder(padding: const EdgeInsets.all(10), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 175, mainAxisExtent: 132, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: products.length, itemBuilder: (_, index) => _productCard(products[index]))),
    ]),
  );

  Widget _productCard(Product product) {
    final bytes = _decode(product.imageData);
    return InkWell(onTap: _saving ? null : () => _addProduct(product), borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Center(child: bytes == null ? const Icon(Icons.inventory_2_outlined, size: 32, color: AppColors.textMuted) : Image.memory(bytes, fit: BoxFit.contain))), Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text('Costo ${_money(product.cost)}  •  Stock ${product.stock}', style: const TextStyle(fontSize: 8, color: AppColors.textSecondary))])));
  }

  void _addProduct(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);
    setState(() {
      _dirty = true;
      if (index >= 0) _items[index] = _items[index].copyWith(purchasedQuantity: _items[index].purchasedQuantity + 1);
      else _items.add(_DraftPurchaseItem(product: product, purchasedQuantity: 1, bonusQuantity: 0, unitCost: product.cost, salePrice: product.price, discount: 0));
    });
  }

  Widget _purchaseItems() => Container(decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Column(children: [Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Expanded(child: Text('Productos de la compra', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))), if (_items.isNotEmpty) Text('$_received recibidas  •  $_bonuses bonificadas', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))])), const Divider(height: 1), Expanded(child: _items.isEmpty ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_shopping_cart_outlined, size: 44, color: AppColors.textMuted), SizedBox(height: 8), Text('Selecciona productos de la izquierda', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)), SizedBox(height: 3), Text('El escáner está activo al abrir esta ventana.', style: TextStyle(fontSize: 10, color: AppColors.textMuted))])) : ListView.separated(padding: const EdgeInsets.all(10), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, index) => _item(index)))]));

  Widget _item(int index) {
    final item = _items[index];
    return _PurchaseItemCard(key: ValueKey(item.product.id), item: item, money: _money, onChanged: (updated) => setState(() { _items[index] = updated; _dirty = true; }), onDelete: () => setState(() { _items.removeAt(index); _dirty = true; }));
  }

  Widget _footer() => Padding(padding: const EdgeInsets.fromLTRB(20, 11, 20, 13), child: Row(children: [if (_editing) OutlinedButton(onPressed: _saving ? null : _cancel, child: const Text('Cancelar')), _stat('Unidades recibidas', '$_received'), const SizedBox(width: 14), _stat('Bonificaciones', '$_bonuses', color: AppColors.successGreen), const Spacer(), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('TOTAL PAGADO', style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700)), Text(_money(_total), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.primary))]), const SizedBox(width: 16), FilledButton.icon(onPressed: _saving || _items.isEmpty ? null : _save, icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(_editing ? Icons.save_outlined : Icons.check), label: Text(_saving ? 'Guardando...' : (_editing ? 'Guardar cambios' : 'Guardar compra')))]));

  Widget _stat(String label, String value, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textMuted)), const SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))]);

  Future<void> _pickDate() async { final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date); if (picked != null && mounted) setState(() { _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute, _date.second); _dirty = true; }); }

  Future<void> _cancel() async {
    if (!_editing || !_dirty) { Navigator.pop(context, false); return; }
    final leave = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('¿Cancelar modificación?'), content: const Text('Tienes cambios sin guardar. Si sales ahora, se perderán.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar salida')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir sin guardar'))]));
    if (leave == true && mounted) Navigator.pop(context, false);
  }

  Future<void> _save() async {
    if (_distributor == null || _distributor!.trim().isEmpty) { _error('Selecciona una distribuidora.'); return; }
    if (_items.isEmpty) { _error('Agrega al menos un producto.'); return; }
    setState(() => _saving = true);
    try {
      final productProvider = context.read<ProductProvider>();
      if (_editing) {
        final oldItems = {for (final item in widget.purchase!.items) item.productId: item};
        final updateCosts = <String>{};
        final updatePrices = <String>{};
        for (final item in _items) {
          final old = oldItems[item.product.id];
          final baseCost = old != null && old.previousCost != null && (item.product.cost - old.unitCost).abs() < 0.0001 ? old.previousCost! : item.product.cost;
          final basePrice = old != null && old.previousSalePrice != null && (item.product.price - old.salePrice).abs() < 0.0001 ? old.previousSalePrice! : item.product.price;
          if (item.purchasedQuantity > 0 && (item.unitCost - baseCost).abs() > 0.0001) updateCosts.add(item.product.id);
          if (item.purchasedQuantity > 0 && (item.salePrice - basePrice).abs() > 0.0001) updatePrices.add(item.product.id);
        }
        if (updateCosts.isNotEmpty) {
          final changes = _items.where((item) => updateCosts.contains(item.product.id)).map((item) => _CostChange(item.product, item.unitCost)).toList();
          final decisions = await showDialog<Map<String, _CostDecision>>(context: context, barrierDismissible: false, builder: (_) => _CostChangesDialog(changes));
          if (!mounted || decisions == null) { setState(() => _saving = false); return; }
          updateCosts.removeWhere((id) => decisions[id]?.updateCost != true);
        }
        final updated = PurchaseRecord(id: widget.purchase!.id, invoiceNumber: _invoiceController.text.trim(), distributorName: _distributor!.trim(), arrivalAt: DateTime(_date.year, _date.month, _date.day, widget.purchase!.arrivalAt.hour, widget.purchase!.arrivalAt.minute, widget.purchase!.arrivalAt.second), paymentMethod: widget.purchase!.paymentMethod, items: _items.map((item) => PurchaseItemRecord(productId: item.product.id, productName: item.product.name, unit: item.product.unit, barcode: item.product.barcode, imageData: item.product.imageData, unitCost: item.unitCost, previousCost: oldItems[item.product.id]?.previousCost ?? item.product.cost, previousSalePrice: oldItems[item.product.id]?.previousSalePrice ?? item.product.price, quantity: item.purchasedQuantity, bonusQuantity: item.bonusQuantity, totalQuantity: item.received, salePrice: item.salePrice, discount: item.discount, total: item.totalCost, effectiveUnitCost: item.effectiveUnitCost)).toList(), subtotal: _total, discount: _items.fold(0, (sum, item) => sum + item.discount), total: _total);
        final ok = await context.read<PurchasesProvider>().updatePurchase(updated, productProvider);
        if (!ok) throw StateError('No se encontró la compra que se está modificando.');
        if (mounted) Navigator.pop(context, true);
        return;
      }

      final costChanges = <_CostChange>[];
      for (final item in _items) {
        if (item.purchasedQuantity <= 0) continue;
        final current = productProvider.findById(item.product.id);
        if (current != null && (current.cost - item.unitCost).abs() > 0.0001) costChanges.add(_CostChange(current, item.unitCost));
      }
      if (costChanges.isNotEmpty) {
        final decisions = await showDialog<Map<String, _CostDecision>>(context: context, barrierDismissible: false, builder: (_) => _CostChangesDialog(costChanges));
        if (!mounted || decisions == null) { setState(() => _saving = false); return; }
        for (final change in costChanges) if (decisions[change.product.id]?.updateCost == true) productProvider.updateProduct(change.product.copyWith(cost: change.newCost));
      }
      for (final item in _items) {
        final current = productProvider.findById(item.product.id);
        if (current == null) continue;
        productProvider.updateProduct(current.copyWith(stock: current.stock + item.received, price: item.purchasedQuantity > 0 ? item.salePrice : current.price));
      }
      final purchase = PurchaseRecord(id: IdGenerator.newId(), invoiceNumber: _invoiceController.text.trim(), distributorName: _distributor!.trim(), arrivalAt: DateTime(_date.year, _date.month, _date.day, DateTime.now().hour, DateTime.now().minute, DateTime.now().second), paymentMethod: 'Contado', items: _items.map((item) => PurchaseItemRecord(productId: item.product.id, productName: item.product.name, unit: item.product.unit, barcode: item.product.barcode, imageData: item.product.imageData, unitCost: item.unitCost, previousCost: item.product.cost, previousSalePrice: item.product.price, quantity: item.purchasedQuantity, bonusQuantity: item.bonusQuantity, totalQuantity: item.received, salePrice: item.salePrice, discount: item.discount, total: item.totalCost, effectiveUnitCost: item.effectiveUnitCost)).toList(), subtotal: _total, discount: _items.fold(0, (sum, item) => sum + item.discount), total: _total);
      context.read<PurchasesProvider>().addPurchase(purchase);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _error('No se pudo guardar la compra: $error');
    }
  }

  void _error(String message) => AppAlert.show(context, message, title: 'No se puede continuar', type: AppAlertType.error);
  Uint8List? _decode(String value) { if (value.trim().isEmpty) return null; try { return base64Decode(value.contains(',') ? value.split(',').last : value); } catch (_) { return null; } }
}

class _DraftPurchaseItem {
  final Product product;
  final int purchasedQuantity;
  final int bonusQuantity;
  final double unitCost;
  final double salePrice;
  final double discount;
  const _DraftPurchaseItem({required this.product, required this.purchasedQuantity, required this.bonusQuantity, required this.unitCost, required this.salePrice, required this.discount});
  int get received => purchasedQuantity + bonusQuantity;
  double get totalCost => (purchasedQuantity * unitCost - discount).clamp(0, double.infinity).toDouble();
  double get effectiveUnitCost => received == 0 ? 0 : totalCost / received;
  _DraftPurchaseItem copyWith({int? purchasedQuantity, int? bonusQuantity, double? unitCost, double? salePrice, double? discount}) => _DraftPurchaseItem(product: product, purchasedQuantity: purchasedQuantity ?? this.purchasedQuantity, bonusQuantity: bonusQuantity ?? this.bonusQuantity, unitCost: unitCost ?? this.unitCost, salePrice: salePrice ?? this.salePrice, discount: discount ?? this.discount);
}

class _PurchaseItemCard extends StatefulWidget {
  final _DraftPurchaseItem item;
  final String Function(double) money;
  final ValueChanged<_DraftPurchaseItem> onChanged;
  final VoidCallback onDelete;
  const _PurchaseItemCard({super.key, required this.item, required this.money, required this.onChanged, required this.onDelete});
  @override State<_PurchaseItemCard> createState() => _PurchaseItemCardState();
}

class _PurchaseItemCardState extends State<_PurchaseItemCard> {
  late final TextEditingController _quantity = TextEditingController(text: widget.item.purchasedQuantity.toString());
  late final TextEditingController _bonus = TextEditingController(text: widget.item.bonusQuantity.toString());
  late final TextEditingController _cost = TextEditingController(text: widget.item.unitCost.toStringAsFixed(2));
  late final TextEditingController _discount = TextEditingController(text: widget.item.discount.toStringAsFixed(2));
  late final TextEditingController _sale = TextEditingController(text: widget.item.salePrice.toStringAsFixed(2));
  @override void dispose() { _quantity.dispose(); _bonus.dispose(); _cost.dispose(); _discount.dispose(); _sale.dispose(); super.dispose(); }
  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  double _double(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
  void _emit() => widget.onChanged(widget.item.copyWith(purchasedQuantity: _int(_quantity).clamp(0, 999999), bonusQuantity: _int(_bonus).clamp(0, 999999), unitCost: _double(_cost).clamp(0, double.infinity), discount: _double(_discount).clamp(0, double.infinity), salePrice: _double(_sale).clamp(0, double.infinity)));
  void _step(TextEditingController c, int amount) { c.text = (_int(c) + amount).clamp(0, 999999).toString(); _emit(); setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final bytes = item.product.imageData.trim().isEmpty ? null : _decode(item.product.imageData);
    final baseStock = item.product.stock;
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [SizedBox(width: 48, height: 48, child: bytes == null ? const Icon(Icons.image_outlined, color: AppColors.textMuted) : Image.memory(bytes, fit: BoxFit.contain)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('Actual: costo ${widget.money(item.product.cost)}  •  venta ${widget.money(item.product.price)}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary))])), IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed, size: 19))]),
      const SizedBox(height: 9),
      Wrap(spacing: 7, runSpacing: 7, children: [_field(_quantity, 'Compradas', Icons.shopping_cart_outlined, quantity: true), _field(_bonus, 'Bonificadas', Icons.card_giftcard_outlined, quantity: true), _field(_cost, 'Costo unitario', Icons.price_change_outlined), _field(_discount, 'Descuento', Icons.discount_outlined), _field(_sale, 'Precio venta', Icons.sell_outlined)]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: Text('Recibidas: ${item.received}  •  Total: ${widget.money(item.totalCost)}  •  Costo efectivo: ${widget.money(item.effectiveUnitCost)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textSecondary))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: AppColors.successGreen.withAlpha(18), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.successGreen.withAlpha(80))), child: Text('Stock $baseStock → ${baseStock + item.received}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.successGreen)))])
    ]));
  }

  Widget _field(TextEditingController c, String label, IconData icon, {bool quantity = false}) => SizedBox(width: quantity ? 125 : 145, child: Container(height: 52, padding: const EdgeInsets.fromLTRB(7, 5, 5, 4), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Expanded(child: Row(children: [Icon(icon, size: 15, color: AppColors.textSecondary), const SizedBox(width: 4), Expanded(child: TextField(controller: c, keyboardType: TextInputType.numberWithOptions(decimal: true), textAlign: quantity ? TextAlign.center : TextAlign.left, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero), onChanged: (_) => _emit())), if (quantity) ...[_stepButton(Icons.remove, 'Disminuir', () => _step(c, -1)), _stepButton(Icons.add, 'Aumentar', () => _step(c, 1))]])])));
  Widget _stepButton(IconData icon, String tooltip, VoidCallback onPressed) => SizedBox(width: 21, height: 27, child: IconButton(tooltip: tooltip, onPressed: onPressed, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, iconSize: 14, icon: Icon(icon)));
  Uint8List? _decode(String value) { try { return base64Decode(value.contains(',') ? value.split(',').last : value); } catch (_) { return null; } }
}

class _CostChange { final Product product; final double newCost; const _CostChange(this.product, this.newCost); }
class _CostDecision { final bool updateCost; final bool skipFuture; const _CostDecision({required this.updateCost, required this.skipFuture}); }

class _CostChangesDialog extends StatefulWidget {
  final List<_CostChange> changes;
  const _CostChangesDialog(this.changes);
  @override State<_CostChangesDialog> createState() => _CostChangesDialogState();
}
class _CostChangesDialogState extends State<_CostChangesDialog> {
  final _resolved = <String>{};
  final _decisions = <String, _CostDecision>{};
  void _resolve(_CostChange change, bool update) { _resolved.add(change.product.id); _decisions[change.product.id] = _CostDecision(updateCost: update, skipFuture: false); if (_resolved.length == widget.changes.length) Navigator.pop(context, _decisions); else setState(() {}); }
  void _skipAll() { for (final change in widget.changes) _decisions[change.product.id] = const _CostDecision(updateCost: false, skipFuture: false); Navigator.pop(context, _decisions); }
  @override Widget build(BuildContext context) => Dialog(insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600), child: Column(mainAxisSize: MainAxisSize.min, children: [Padding(padding: const EdgeInsets.fromLTRB(18, 14, 10, 10), child: Row(children: [const Icon(Icons.price_change_outlined, color: AppColors.primary, size: 22), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Actualizar costos', style: AppTextStyles.sectionTitle), const SizedBox(height: 2), Text('Estos ${widget.changes.length} productos tienen un costo diferente al registrado.', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))])), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20))])), const Divider(height: 1), Expanded(child: ListView.separated(padding: const EdgeInsets.fromLTRB(12, 10, 12, 6), itemCount: widget.changes.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, index) => _card(widget.changes[index]))), Padding(padding: const EdgeInsets.fromLTRB(14, 2, 14, 10), child: Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _skipAll, icon: const Icon(Icons.skip_next_outlined, size: 17), label: const Text('Saltar todos'))))]));
  Widget _card(_CostChange change) { final done = _resolved.contains(change.product.id); return Opacity(opacity: done ? 0.5 : 1, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(change.product.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Row(children: [Expanded(child: Text('Actual ${'\$${change.product.cost.toStringAsFixed(2)}'}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))), Text('Nuevo ${'\$${change.newCost.toStringAsFixed(2)}'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))]), const SizedBox(height: 8), if (!done) Row(children: [Expanded(child: OutlinedButton(onPressed: () => _resolve(change, false), child: const Text('Saltar'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: () => _resolve(change, true), child: const Text('Registrar costo')))])]))); }
}
