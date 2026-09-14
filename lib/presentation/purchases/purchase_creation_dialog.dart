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

  static Future<bool?> show(BuildContext context, {PurchaseRecord? purchase}) => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PurchaseCreationDialog(purchase: purchase),
      );

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
  double get _total => _items.fold(0, (sum, item) => sum + item.totalCost);
  int get _received => _items.fold(0, (sum, item) => sum + item.received);
  int get _bonuses => _items.fold(0, (sum, item) => sum + item.bonusQuantity);

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
    final provider = context.read<ProductProvider>();
    setState(() {
      _items
        ..clear()
        ..addAll(purchase.items.map((item) {
          final product = provider.findById(item.productId) ?? Product(
            id: item.productId,
            name: item.productName,
            unit: item.unit,
            department: '',
            brand: '',
            cost: item.previousCost ?? item.unitCost,
            price: item.previousSalePrice ?? item.salePrice,
            stock: 0,
            minStock: 0,
            maxStock: 0,
            category: '',
            barcode: item.barcode,
            imageData: item.imageData,
          );
          final original = item.discountPercent != null && item.discountPercent! > 0
              ? item.unitCost / (1 - item.discountPercent! / 100)
              : item.unitCost;
          return _DraftPurchaseItem(
            product: product,
            purchasedQuantity: item.quantity,
            bonusQuantity: item.bonusQuantity,
            originalUnitCost: original,
            discountedUnitCost: item.unitCost,
            discountPercent: item.discountPercent ?? 0,
            iva: item.iva,
            salePrice: item.salePrice,
          );
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

  List<Product> _visibleProducts(ProductProvider provider) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return provider.products;
    return provider.products.where((p) => p.name.toLowerCase().contains(query) || p.barcode.toLowerCase().contains(query) || p.brand.toLowerCase().contains(query)).toList();
  }

  int _oldQuantity(String productId) {
    if (!_editing) return 0;
    for (final item in widget.purchase!.items) {
      if (item.productId == productId) return item.totalQuantity;
    }
    return 0;
  }

  int _baseStock(Product product) => (product.stock - _oldQuantity(product.id)).clamp(0, 1 << 30).toInt();

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
          Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: Row(children: [
            Expanded(flex: 5, child: _productPicker(products)),
            const SizedBox(width: 14),
            Expanded(flex: 6, child: _purchaseItems()),
          ]))),
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
        Expanded(flex: 2, child: DropdownButtonFormField<String>(initialValue: _distributor, isExpanded: true, decoration: const InputDecoration(labelText: 'Distribuidora', prefixIcon: Icon(Icons.storefront_outlined), border: OutlineInputBorder(), isDense: true), items: distributors.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(), onChanged: _saving ? null : (value) => setState(() { _distributor = value; _dirty = true; }))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: _invoiceController, enabled: !_saving, onChanged: (_) => setState(() => _dirty = true), decoration: const InputDecoration(labelText: 'N.º de factura', prefixIcon: Icon(Icons.receipt_long_outlined), border: OutlineInputBorder(), isDense: true))),
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
      if (index >= 0) {
        _items[index] = _items[index].copyWith(purchasedQuantity: _items[index].purchasedQuantity + 1);
      } else {
        _items.add(_DraftPurchaseItem(product: product, purchasedQuantity: 1, bonusQuantity: 0, originalUnitCost: null, discountedUnitCost: product.cost, discountPercent: 0, iva: null, salePrice: product.price));
      }
    });
  }

  Widget _purchaseItems() => Container(decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Column(children: [Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Expanded(child: Text('Productos de la compra', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))), if (_items.isNotEmpty) Text('$_received recibidas  •  $_bonuses bonificadas', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))])), const Divider(height: 1), Expanded(child: _items.isEmpty ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_shopping_cart_outlined, size: 44, color: AppColors.textMuted), SizedBox(height: 8), Text('Selecciona productos de la izquierda', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)), SizedBox(height: 3), Text('El escáner está activo al abrir esta ventana.', style: TextStyle(fontSize: 10, color: AppColors.textMuted))])) : ListView.separated(padding: const EdgeInsets.all(10), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, index) => _item(index)))]));

  Widget _item(int index) {
    final item = _items[index];
    return _PurchaseItemCard(
      key: ValueKey(item.product.id),
      item: item,
      money: _money,
      baseStock: _baseStock(item.product),
      onChanged: (updated) => setState(() { _items[index] = updated; _dirty = true; }),
      onDelete: () => setState(() { _items.removeAt(index); _dirty = true; }),
    );
  }

  Widget _footer() => Padding(padding: const EdgeInsets.fromLTRB(20, 11, 20, 13), child: Row(children: [if (_editing) OutlinedButton(onPressed: _saving ? null : _cancel, child: const Text('Cancelar')), _stat('Unidades recibidas', '$_received'), const SizedBox(width: 14), _stat('Bonificaciones', '$_bonuses', color: AppColors.successGreen), const Spacer(), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('TOTAL PAGADO', style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700)), Text(_money(_total), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.primary))]), const SizedBox(width: 16), FilledButton.icon(onPressed: _saving || _items.isEmpty ? null : _save, icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(_editing ? Icons.save_outlined : Icons.check), label: Text(_saving ? 'Guardando...' : (_editing ? 'Guardar cambios' : 'Guardar compra')))]));

  Widget _stat(String label, String value, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textMuted)), const SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))]);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date);
    if (picked != null && mounted) setState(() { _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute, _date.second); _dirty = true; });
  }

  Future<void> _cancel() async {
    if (!_editing || !_dirty) { Navigator.pop(context, false); return; }
    final leave = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('¿Cancelar modificación?'), content: const Text('Tienes cambios sin guardar. Si sales ahora, se perderán.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar salida')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir sin guardar'))]));
    if (leave == true && mounted) Navigator.pop(context, false);
  }

  Future<void> _save() async {
    if (_distributor == null || _distributor!.trim().isEmpty) { _error('Selecciona una distribuidora.'); return; }
    if (_items.isEmpty) { _error('Agrega al menos un producto.'); return; }
    for (final item in _items) {
      if (item.purchasedQuantity <= 0) continue;
      if (item.originalUnitCost == null && item.discountedUnitCost <= 0) { _error('Ingresa el precio del producto en ${item.product.name}.'); return; }
      if (item.originalUnitCost != null && item.discountedUnitCost <= 0) { _error('El precio con descuento no puede ser cero en ${item.product.name}.'); return; }
    }
    setState(() => _saving = true);
    try {
      final productProvider = context.read<ProductProvider>();
      final oldItems = _editing ? {for (final item in widget.purchase!.items) item.productId: item} : <String, PurchaseItemRecord>{};
      final costChanges = <_CostChange>[];
      final updatePriceIds = <String>{};
      for (final item in _items) {
        if (item.purchasedQuantity <= 0) continue;
        final current = productProvider.findById(item.product.id);
        if (current != null && (current.cost - item.discountedUnitCost).abs() > 0.0001) {
          final old = oldItems[item.product.id];
          final changedFromOriginal = !_editing || old == null || (old.unitCost - item.discountedUnitCost).abs() > 0.0001;
          if (changedFromOriginal) costChanges.add(_CostChange(current, item.discountedUnitCost));
        }
        final old = oldItems[item.product.id];
        if (!_editing || old == null || (old.salePrice - item.salePrice).abs() > 0.0001) updatePriceIds.add(item.product.id);
      }

      Set<String> updateCostIds = <String>{};
      if (costChanges.isNotEmpty) {
        final decisions = await showDialog<Map<String, _CostDecision>>(context: context, barrierDismissible: false, builder: (_) => _CostChangesDialog(costChanges));
        if (!mounted || decisions == null) { setState(() => _saving = false); return; }
        updateCostIds = {for (final change in costChanges) if (decisions[change.product.id]?.updateCost == true) change.product.id};
        if (!_editing) {
          for (final change in costChanges) {
            if (updateCostIds.contains(change.product.id)) productProvider.updateProduct(change.product.copyWith(cost: change.newCost));
          }
        }
      }

      final records = _items.map((item) {
        final old = oldItems[item.product.id];
        final discountAmountPerUnit = item.originalUnitCost == null ? 0 : (item.originalUnitCost! - item.discountedUnitCost).clamp(0, double.infinity).toDouble();
        return PurchaseItemRecord(
          productId: item.product.id,
          productName: item.product.name,
          unit: item.product.unit,
          barcode: item.product.barcode,
          imageData: item.product.imageData,
          unitCost: item.discountedUnitCost,
          previousCost: old?.previousCost ?? item.product.cost,
          previousSalePrice: old?.previousSalePrice ?? item.product.price,
          quantity: item.purchasedQuantity,
          bonusQuantity: item.bonusQuantity,
          totalQuantity: item.received,
          salePrice: item.salePrice,
          discount: discountAmountPerUnit * item.purchasedQuantity,
          discountPercent: item.discountPercent > 0 ? item.discountPercent : null,
          iva: item.iva,
          total: item.totalCost,
          effectiveUnitCost: item.effectiveUnitCost,
        );
      }).toList();

      if (_editing) {
        final previous = widget.purchase!;
        final updated = PurchaseRecord(
          id: previous.id,
          invoiceNumber: _invoiceController.text.trim(),
          distributorName: _distributor!.trim(),
          arrivalAt: DateTime(_date.year, _date.month, _date.day, previous.arrivalAt.hour, previous.arrivalAt.minute, previous.arrivalAt.second),
          paymentMethod: previous.paymentMethod,
          items: records,
          subtotal: _items.fold(0, (sum, item) => sum + item.netSubtotal),
          discount: records.fold(0, (sum, item) => sum + item.discount),
          total: _total,
        );
        final ok = await context.read<PurchasesProvider>().updatePurchase(updated, productProvider, updateCostIds: updateCostIds, updatePriceIds: updatePriceIds);
        if (!ok) throw StateError('La compra ya no existe.');
      } else {
        for (final item in _items) {
          final current = productProvider.findById(item.product.id);
          if (current == null) continue;
          productProvider.updateProduct(current.copyWith(stock: current.stock + item.received, price: item.purchasedQuantity > 0 ? item.salePrice : current.price));
        }
        context.read<PurchasesProvider>().addPurchase(PurchaseRecord(
          id: IdGenerator.newId(),
          invoiceNumber: _invoiceController.text.trim(),
          distributorName: _distributor!.trim(),
          arrivalAt: DateTime(_date.year, _date.month, _date.day, DateTime.now().hour, DateTime.now().minute, DateTime.now().second),
          paymentMethod: 'Contado',
          items: records,
          subtotal: _items.fold(0, (sum, item) => sum + item.netSubtotal),
          discount: records.fold(0, (sum, item) => sum + item.discount),
          total: _total,
        ));
      }
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
  final double? originalUnitCost;
  final double discountedUnitCost;
  final double discountPercent;
  final double? iva;
  final double salePrice;

  const _DraftPurchaseItem({required this.product, required this.purchasedQuantity, required this.bonusQuantity, required this.originalUnitCost, required this.discountedUnitCost, required this.discountPercent, required this.iva, required this.salePrice});
  int get received => purchasedQuantity + bonusQuantity;
  double get discountAmountPerUnit => originalUnitCost == null ? 0 : (originalUnitCost! - discountedUnitCost).clamp(0, double.infinity).toDouble();
  double get discountAmount => discountAmountPerUnit * purchasedQuantity;
  double get netSubtotal => purchasedQuantity * discountedUnitCost;
  double get totalCost => (netSubtotal + (iva ?? 0)).clamp(0, double.infinity).toDouble();
  double get effectiveUnitCost => received == 0 ? 0 : totalCost / received;

  _DraftPurchaseItem copyWith({int? purchasedQuantity, int? bonusQuantity, double? originalUnitCost, bool clearOriginal = false, double? discountedUnitCost, double? discountPercent, double? iva, bool clearIva = false, double? salePrice}) => _DraftPurchaseItem(
    product: product,
    purchasedQuantity: purchasedQuantity ?? this.purchasedQuantity,
    bonusQuantity: bonusQuantity ?? this.bonusQuantity,
    originalUnitCost: clearOriginal ? null : (originalUnitCost ?? this.originalUnitCost),
    discountedUnitCost: discountedUnitCost ?? this.discountedUnitCost,
    discountPercent: discountPercent ?? this.discountPercent,
    iva: clearIva ? null : (iva ?? this.iva),
    salePrice: salePrice ?? this.salePrice,
  );
}

class _PurchaseItemCard extends StatefulWidget {
  final _DraftPurchaseItem item;
  final String Function(double) money;
  final int baseStock;
  final ValueChanged<_DraftPurchaseItem> onChanged;
  final VoidCallback onDelete;
  const _PurchaseItemCard({super.key, required this.item, required this.money, required this.baseStock, required this.onChanged, required this.onDelete});
  @override State<_PurchaseItemCard> createState() => _PurchaseItemCardState();
}

class _PurchaseItemCardState extends State<_PurchaseItemCard> {
  late final TextEditingController _purchasedController;
  late final TextEditingController _bonusController;
  late final TextEditingController _originalController;
  late final TextEditingController _discountedController;
  late final TextEditingController _discountController;
  late final TextEditingController _ivaController;
  late final TextEditingController _saleController;
  bool _updating = false;
  bool _originalAuto = false;
  bool _discountedAuto = false;

  @override
  void initState() {
    super.initState();
    _purchasedController = TextEditingController(text: '${widget.item.purchasedQuantity}');
    _bonusController = TextEditingController(text: '${widget.item.bonusQuantity}');
    _originalController = TextEditingController(text: widget.item.originalUnitCost?.toStringAsFixed(2) ?? '');
    _discountedController = TextEditingController(text: widget.item.discountedUnitCost.toStringAsFixed(2));
    _discountController = TextEditingController(text: widget.item.discountPercent > 0 ? widget.item.discountPercent.toStringAsFixed(2) : '');
    _ivaController = TextEditingController(text: widget.item.iva?.toStringAsFixed(2) ?? '');
    _saleController = TextEditingController(text: widget.item.salePrice.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(covariant _PurchaseItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.item;
    final current = widget.item;
    if (old.purchasedQuantity != current.purchasedQuantity && _integer(_purchasedController) != current.purchasedQuantity) _replace(_purchasedController, '${current.purchasedQuantity}');
    if (old.bonusQuantity != current.bonusQuantity && _integer(_bonusController) != current.bonusQuantity) _replace(_bonusController, '${current.bonusQuantity}');
    if (old.originalUnitCost != current.originalUnitCost && _number(_originalController) != (current.originalUnitCost ?? 0)) _replace(_originalController, current.originalUnitCost?.toStringAsFixed(2) ?? '');
    if (old.discountedUnitCost != current.discountedUnitCost && _number(_discountedController) != current.discountedUnitCost) _replace(_discountedController, current.discountedUnitCost.toStringAsFixed(2));
    if (old.discountPercent != current.discountPercent && _number(_discountController) != current.discountPercent) _replace(_discountController, current.discountPercent > 0 ? current.discountPercent.toStringAsFixed(2) : '');
    if (old.iva != current.iva && _numberOrNull(_ivaController) != current.iva) _replace(_ivaController, current.iva?.toStringAsFixed(2) ?? '');
    if (old.salePrice != current.salePrice && _number(_saleController) != current.salePrice) _replace(_saleController, current.salePrice.toStringAsFixed(2));
  }

  void _replace(TextEditingController controller, String value) => controller.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
  int _integer(TextEditingController controller) => int.tryParse(controller.text.trim()) ?? 0;
  double _number(TextEditingController controller) => double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
  double? _numberOrNull(TextEditingController controller) { final text = controller.text.trim().replaceAll(',', '.'); return text.isEmpty ? null : double.tryParse(text); }

  void _syncPrice({required bool fromOriginal}) {
    if (_updating) return;
    final discount = _number(_discountController).clamp(0, 100).toDouble();
    final sourceText = fromOriginal ? _originalController.text : _discountedController.text;
    final source = double.tryParse(sourceText.trim().replaceAll(',', '.'));
    if (source == null || source < 0) return;
    _updating = true;
    if (discount > 0) {
      if (fromOriginal) {
        final value = source * (1 - discount / 100);
        _replace(_discountedController, value.toStringAsFixed(2));
        _originalAuto = false;
        _discountedAuto = true;
      } else {
        final divisor = 1 - discount / 100;
        if (divisor > 0) {
          final value = source / divisor;
          _replace(_originalController, value.toStringAsFixed(2));
          _originalAuto = true;
          _discountedAuto = false;
        }
      }
    } else {
      if (fromOriginal) {
        _replace(_discountedController, source.toStringAsFixed(2));
        _discountedAuto = true;
      } else {
        _replace(_originalController, source.toStringAsFixed(2));
        _originalAuto = true;
      }
    }
    _updating = false;
    _emit();
  }

  void _discountChanged() {
    if (_updating) return;
    final discount = _number(_discountController).clamp(0, 100).toDouble();
    final original = double.tryParse(_originalController.text.trim().replaceAll(',', '.'));
    final discounted = double.tryParse(_discountedController.text.trim().replaceAll(',', '.'));
    if (original != null && original >= 0) {
      _updating = true;
      final value = original * (1 - discount / 100);
      _replace(_discountedController, value.toStringAsFixed(2));
      _discountedAuto = true;
      _originalAuto = false;
      _updating = false;
    } else if (discounted != null && discounted >= 0 && discount > 0) {
      _updating = true;
      final value = discounted / (1 - discount / 100);
      _replace(_originalController, value.toStringAsFixed(2));
      _originalAuto = true;
      _discountedAuto = false;
      _updating = false;
    }
    _emit();
  }

  void _emit() {
    final originalText = _originalController.text.trim().replaceAll(',', '.');
    final original = originalText.isEmpty ? null : double.tryParse(originalText);
    final iva = _numberOrNull(_ivaController);
    widget.onChanged(widget.item.copyWith(
      purchasedQuantity: _integer(_purchasedController).clamp(0, 1 << 30).toInt(),
      bonusQuantity: _integer(_bonusController).clamp(0, 1 << 30).toInt(),
      originalUnitCost: original,
      discountedUnitCost: _number(_discountedController).clamp(0, double.infinity).toDouble(),
      discountPercent: _number(_discountController).clamp(0, 100).toDouble(),
      iva: iva,
      salePrice: _number(_saleController).clamp(0, double.infinity).toDouble(),
    ));
  }

  void _step(TextEditingController controller, int delta) {
    controller.text = (_integer(controller) + delta).clamp(0, 1 << 30).toInt().toString();
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    _emit();
  }

  @override
  void dispose() {
    _purchasedController.dispose();
    _bonusController.dispose();
    _originalController.dispose();
    _discountedController.dispose();
    _discountController.dispose();
    _ivaController.dispose();
    _saleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(padding: const EdgeInsets.fromLTRB(11, 10, 9, 11), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [_image(item.product.imageData), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), const SizedBox(height: 5), _currentPrices(item.product), const SizedBox(height: 6), _stockPreview(item)])), IconButton(tooltip: 'Eliminar', onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline, size: 20))]),
      const SizedBox(height: 9),
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Column(children: [
        Row(children: [
          Expanded(child: _quantityField(_purchasedController, 'Compradas', Icons.shopping_cart_outlined)), const SizedBox(width: 6),
          Expanded(child: _quantityField(_bonusController, 'Bonificadas', Icons.card_giftcard_outlined)), const SizedBox(width: 6),
          Expanded(child: _readonly('Recibidas', '${item.received}', Icons.inventory_2_outlined)),
        ]),
        const SizedBox(height: 7),
        Row(children: [
          Expanded(child: _priceField(_originalController, 'Precio sin descuento', Icons.sell_outlined, auto: _originalAuto, onChanged: () => _syncPrice(fromOriginal: true))), const SizedBox(width: 6),
          Expanded(child: _numberField(_discountController, 'Descuento (%)', Icons.discount_outlined, onChanged: _discountChanged)), const SizedBox(width: 6),
          Expanded(child: _priceField(_discountedController, 'Precio con descuento', Icons.local_offer_outlined, auto: _discountedAuto, onChanged: () => _syncPrice(fromOriginal: false))),
        ]),
        const SizedBox(height: 7),
        Row(children: [
          Expanded(child: _numberField(_ivaController, 'IVA ($)', Icons.receipt_long_outlined, onChanged: _emit, hint: 'Opcional')), const SizedBox(width: 6),
          Expanded(child: _readonly('Total', widget.money(item.totalCost), Icons.calculate_outlined, color: AppColors.primary)), const SizedBox(width: 6),
          Expanded(child: _numberField(_saleController, 'Nuevo precio', Icons.edit_outlined, onChanged: _emit)),
        ]),
        const SizedBox(height: 7),
        Align(alignment: Alignment.centerLeft, child: Text(item.iva == null ? 'IVA: incluido en el precio' : 'IVA separado: ${widget.money(item.iva!)}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary))),
      ])),
    ]);
  }

  Widget _priceField(TextEditingController controller, String label, IconData icon, {required bool auto, required VoidCallback onChanged}) => Container(height: 53, padding: const EdgeInsets.fromLTRB(7, 5, 7, 4), decoration: BoxDecoration(color: auto ? AppColors.primary.withAlpha(14) : AppColors.inputBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: auto ? AppColors.primary.withAlpha(100) : AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, color: auto ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w600))), if (auto) const Icon(Icons.auto_awesome_outlined, size: 11, color: AppColors.primary)]), const SizedBox(height: 2), Expanded(child: Row(children: [Icon(icon, size: 15, color: auto ? AppColors.primary : AppColors.textSecondary), const SizedBox(width: 4), Expanded(child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: auto ? AppColors.primary : null), decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero), onChanged: (_) => onChanged())]))]));

  Widget _numberField(TextEditingController controller, String label, IconData icon, {required VoidCallback onChanged, String? hint}) => Container(height: 53, padding: const EdgeInsets.fromLTRB(7, 5, 7, 4), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Expanded(child: Row(children: [Icon(icon, size: 15, color: AppColors.textSecondary), const SizedBox(width: 4), Expanded(child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), decoration: InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, hintText: hint), onChanged: (_) => onChanged())]))]));

  Widget _quantityField(TextEditingController controller, String label, IconData icon) => Container(height: 53, padding: const EdgeInsets.fromLTRB(7, 5, 5, 4), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Expanded(child: Row(children: [Icon(icon, size: 15, color: AppColors.textSecondary), const SizedBox(width: 3), Expanded(child: TextField(controller: controller, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800), decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero), onChanged: (_) => _emit())), _stepButton(Icons.remove, 'Disminuir', () => _step(controller, -1)), const SizedBox(width: 2), _stepButton(Icons.add, 'Aumentar', () => _step(controller, 1))]))]));

  Widget _stepButton(IconData icon, String tooltip, VoidCallback onPressed) => SizedBox(width: 21, height: 27, child: IconButton(tooltip: tooltip, onPressed: onPressed, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, iconSize: 14, icon: Icon(icon)));
  Widget _stockPreview(_DraftPurchaseItem item) => Tooltip(message: 'Stock antes de esta compra: ${widget.baseStock}\nStock después de la compra: ${widget.baseStock + item.received}', child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppColors.successGreen.withAlpha(18), borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.successGreen.withAlpha(105))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.inventory_2_outlined, size: 15, color: AppColors.successGreen), const SizedBox(width: 5), Text('Stock ${widget.baseStock} → ${widget.baseStock + item.received}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.successGreen))])));
  Widget _currentPrices(Product product) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.border)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Costo ${widget.money(product.cost)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)), const SizedBox(width: 12), Text('Venta ${widget.money(product.price)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700))]));
  Widget _image(String data) { final bytes = _decode(data); return Container(width: 48, height: 48, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: bytes == null ? const Icon(Icons.image_outlined, size: 21, color: AppColors.textMuted) : Image.memory(bytes, fit: BoxFit.contain)); }
  Uint8List? _decode(String value) { if (value.trim().isEmpty) return null; try { return base64Decode(value.contains(',') ? value.split(',').last : value); } catch (_) { return null; } }
  Widget _readonly(String label, String value, IconData icon, {Color? color}) => Container(height: 53, padding: const EdgeInsets.fromLTRB(7, 5, 7, 4), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: AppColors.textSecondary, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Expanded(child: Row(children: [Icon(icon, size: 15, color: AppColors.textSecondary), const SizedBox(width: 5), Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)))]))]));
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
  final _skipFuture = <String, bool>{};
  final _decisions = <String, _CostDecision>{};
  void _resolve(_CostChange change, bool update) { final id = change.product.id; _resolved.add(id); _decisions[id] = _CostDecision(updateCost: update, skipFuture: _skipFuture[id] ?? false); if (_resolved.length == widget.changes.length) Navigator.pop(context, _decisions); else setState(() {}); }
  void _skipAll() { for (final change in widget.changes) _decisions[change.product.id] = _CostDecision(updateCost: false, skipFuture: _skipFuture[change.product.id] ?? false); Navigator.pop(context, _decisions); }
  @override Widget build(BuildContext context) => Dialog(insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 14, 10, 10), child: Row(children: [const Icon(Icons.price_change_outlined, color: AppColors.primary, size: 22), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Actualizar costos', style: AppTextStyles.sectionTitle), const SizedBox(height: 2), Text('Estos ${widget.changes.length} productos tienen un costo diferente al registrado.', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))])), IconButton(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20))])),
    const Divider(height: 1),
    Expanded(child: ListView.separated(padding: const EdgeInsets.fromLTRB(12, 10, 12, 6), itemCount: widget.changes.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, index) => _costCard(widget.changes[index]))),
    Padding(padding: const EdgeInsets.fromLTRB(14, 2, 14, 10), child: Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _skipAll, icon: const Icon(Icons.skip_next_outlined, size: 17), label: const Text('Saltar todos')))),
  ])));
  Widget _costCard(_CostChange change) { final done = _resolved.contains(change.product.id); final bytes = _decode(change.product.imageData); return Opacity(opacity: done ? 0.5 : 1, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(width: 40, height: 40, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.border)), child: bytes == null ? const Icon(Icons.image_outlined, size: 18, color: AppColors.textMuted) : Image.memory(bytes, fit: BoxFit.contain)), const SizedBox(width: 9), Expanded(child: Text(change.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))), if (done) const Icon(Icons.check_circle_outline, color: AppColors.successGreen, size: 19)]),
    const SizedBox(height: 7),
    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8)), child: Row(children: [Expanded(child: _price('Actual', change.product.cost)), const Icon(Icons.arrow_forward_outlined, size: 17, color: AppColors.textMuted), Expanded(child: _price('Nuevo', change.newCost, color: AppColors.successGreen))])),
    const SizedBox(height: 6),
    Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.primary.withAlpha(70))), child: const Text('El nuevo costo reemplazará al anterior.', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600))),
    const SizedBox(height: 6),
    Row(children: [Expanded(child: OutlinedButton.icon(onPressed: done ? null : () => _resolve(change, true), icon: const Icon(Icons.check, size: 15), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 8)), label: FittedBox(fit: BoxFit.scaleDown, child: Text('Registrar ${change.newCost.toStringAsFixed(2)} como costo')))), const SizedBox(width: 7), SizedBox(width: 102, child: OutlinedButton.icon(onPressed: done ? null : () => _resolve(change, false), icon: const Icon(Icons.close, size: 15), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 8)), label: const Text('Saltar', maxLines: 1)))]),
    const SizedBox(height: 2),
    Row(children: [SizedBox(width: 30, height: 30, child: Checkbox(value: _skipFuture[change.product.id] ?? false, onChanged: done ? null : (value) => setState(() => _skipFuture[change.product.id] = value ?? false))), const SizedBox(width: 4), const Expanded(child: Text('No volver a preguntarme para este producto', style: TextStyle(fontSize: 9))), const SizedBox(width: 5), const Text('Solo esta compra', style: TextStyle(fontSize: 8, color: AppColors.textMuted))]),
  ]))); }
  Widget _price(String label, double value, {Color? color}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textMuted)), const SizedBox(height: 1), Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color))]);
  Uint8List? _decode(String value) { if (value.trim().isEmpty) return null; try { return base64Decode(value.contains(',') ? value.split(',').last : value); } catch (_) { return null; } }
}
