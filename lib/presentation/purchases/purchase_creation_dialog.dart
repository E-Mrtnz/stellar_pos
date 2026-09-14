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

class PurchaseCreationDialog extends StatefulWidget {
  const PurchaseCreationDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PurchaseCreationDialog(),
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

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_barcodeKeyHandler);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_barcodeKeyHandler);
    _invoiceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';

  String _dateText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  KeyEventResult _barcodeKeyHandler(KeyEvent event) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }

    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;

    if (isEnter) {
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
    if (character == null || character.isEmpty || character.trim().isEmpty) {
      return KeyEventResult.ignored;
    }

    final now = DateTime.now();
    _scannerBuffer = _lastScannerKey == null || now.difference(_lastScannerKey!) > _scannerTimeout
        ? character
        : _scannerBuffer + character;
    _lastScannerKey = now;
    return KeyEventResult.handled;
  }

  List<Product> _visibleProducts(ProductProvider provider) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return provider.products;
    return provider.products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.brand.toLowerCase().contains(query);
    }).toList();
  }

  double get _total => _items.fold(0, (sum, item) => sum + item.totalCost);
  int get _received => _items.fold(0, (sum, item) => sum + item.received);
  int get _bonuses => _items.fold(0, (sum, item) => sum + item.bonusQuantity);

  @override
  Widget build(BuildContext context) {
    final products = _visibleProducts(context.watch<ProductProvider>());
    final distributors = context.watch<ProvidersProvider>().distributors;

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 850),
        child: Column(
          children: [
            _header(),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(14), child: _purchaseInfo(distributors)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    Expanded(flex: 5, child: _productPicker(products)),
                    const SizedBox(width: 14),
                    Expanded(flex: 6, child: _purchaseItems()),
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

  Widget _header() {
    return Padding(
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
  }

  Widget _purchaseInfo(List<String> distributors) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            initialValue: _distributor,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Distribuidora',
              prefixIcon: Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: distributors.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: _saving ? null : (value) => setState(() => _distributor = value),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _invoiceController,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'N.º de factura',
              prefixIcon: Icon(Icons.receipt_long_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: _saving ? null : _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha',
                prefixIcon: Icon(Icons.calendar_today_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: Text(_dateText(_date)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.payments_outlined, size: 18, color: AppColors.successGreen),
            SizedBox(width: 7),
            Text('Contado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ],
    );
  }

  Widget _productPicker(List<Product> products) {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(children: [
              const Expanded(child: Text('Agregar productos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
              Text('${products.length} disponibles', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('No hay productos registrados.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 175,
                      mainAxisExtent: 132,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, index) => _productCard(products[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(Product product) {
    final bytes = _decode(product.imageData);
    return InkWell(
      onTap: _saving ? null : () => _addProduct(product),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: bytes == null ? const Icon(Icons.inventory_2_outlined, size: 32, color: AppColors.textMuted) : Image.memory(bytes, fit: BoxFit.contain))),
            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Costo ${_money(product.cost)}  •  Stock ${product.stock}', style: const TextStyle(fontSize: 8, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _addProduct(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);
    setState(() {
      if (index >= 0) {
        final item = _items[index];
        _items[index] = item.copyWith(purchasedQuantity: item.purchasedQuantity + 1);
      } else {
        _items.add(_DraftPurchaseItem(
          product: product,
          purchasedQuantity: 1,
          bonusQuantity: 0,
          unitCost: product.cost,
          salePrice: product.price,
          discount: 0,
        ));
      }
    });
  }

  Widget _purchaseItems() {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Expanded(child: Text('Productos de la compra', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
              if (_items.isNotEmpty) Text('$_received recibidas  •  $_bonuses bonificadas', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_shopping_cart_outlined, size: 44, color: AppColors.textMuted),
                      SizedBox(height: 8),
                      Text('Selecciona productos de la izquierda', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      SizedBox(height: 3),
                      Text('El escáner está activo al abrir esta ventana.', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ]),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _item(index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _item(int index) {
    final item = _items[index];
    return _PurchaseItemCard(
      key: ValueKey(item.product.id),
      item: item,
      money: _money,
      onChanged: (updated) => setState(() => _items[index] = updated),
      onDelete: () => setState(() => _items.removeAt(index)),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 11, 20, 13),
      child: Row(
        children: [
          _stat('Unidades recibidas', '$_received'),
          const SizedBox(width: 14),
          _stat('Bonificaciones', '$_bonuses', color: AppColors.successGreen),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('TOTAL PAGADO', style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
              Text(_money(_total), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ],
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: _saving || _items.isEmpty ? null : _save,
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
            label: Text(_saving ? 'Guardando...' : 'Guardar compra'),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: _date);
    if (picked != null && mounted) setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
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
      final costChanges = <_CostChange>[];

      for (final item in _items) {
        if (item.purchasedQuantity <= 0) continue;
        final current = productProvider.findById(item.product.id);
        if (current != null && (current.cost - item.unitCost).abs() > 0.0001) {
          costChanges.add(_CostChange(current, item.unitCost));
        }
      }

      if (costChanges.isNotEmpty) {
        final decisions = await showDialog<Map<String, _CostDecision>>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _CostChangesDialog(costChanges),
        );
        if (!mounted || decisions == null) {
          setState(() => _saving = false);
          return;
        }

        for (final change in costChanges) {
          final decision = decisions[change.product.id];
          if (decision?.updateCost == true) {
            productProvider.updateProduct(change.product.copyWith(cost: change.newCost));
          }
        }
      }

      for (final item in _items) {
        final current = productProvider.findById(item.product.id);
        if (current == null) continue;
        productProvider.updateProduct(
          current.copyWith(
            stock: current.stock + item.received,
            price: item.purchasedQuantity > 0 ? item.salePrice : current.price,
          ),
        );
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
          totalQuantity: item.received,
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

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  const _DraftPurchaseItem({
    required this.product,
    required this.purchasedQuantity,
    required this.bonusQuantity,
    required this.unitCost,
    required this.salePrice,
    required this.discount,
  });

  int get received => purchasedQuantity + bonusQuantity;

  double get totalCost =>
      (purchasedQuantity * unitCost - discount).clamp(0, double.infinity).toDouble();

  double get effectiveUnitCost => received == 0 ? 0 : totalCost / received;

  _DraftPurchaseItem copyWith({
    int? purchasedQuantity,
    int? bonusQuantity,
    double? unitCost,
    double? salePrice,
    double? discount,
  }) {
    return _DraftPurchaseItem(
      product: product,
      purchasedQuantity: purchasedQuantity ?? this.purchasedQuantity,
      bonusQuantity: bonusQuantity ?? this.bonusQuantity,
      unitCost: unitCost ?? this.unitCost,
      salePrice: salePrice ?? this.salePrice,
      discount: discount ?? this.discount,
    );
  }
}

class _PurchaseItemCard extends StatefulWidget {
  final _DraftPurchaseItem item;
  final String Function(double) money;
  final ValueChanged<_DraftPurchaseItem> onChanged;
  final VoidCallback onDelete;

  const _PurchaseItemCard({
    super.key,
    required this.item,
    required this.money,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_PurchaseItemCard> createState() => _PurchaseItemCardState();
}

class _PurchaseItemCardState extends State<_PurchaseItemCard> {
  late final TextEditingController _purchasedController;
  late final TextEditingController _bonusController;
  late final TextEditingController _costController;
  late final TextEditingController _discountController;
  late final TextEditingController _saleController;

  @override
  void initState() {
    super.initState();
    _purchasedController = TextEditingController(text: '${widget.item.purchasedQuantity}');
    _bonusController = TextEditingController(text: '${widget.item.bonusQuantity}');
    _costController = TextEditingController(text: _display(widget.item.unitCost));
    _discountController = TextEditingController(text: _display(widget.item.discount));
    _saleController = TextEditingController(text: _display(widget.item.salePrice));
  }

  String _display(double value) {
    if (widget.item.purchasedQuantity == 0 && widget.item.bonusQuantity > 0) return '';
    return value.toStringAsFixed(2);
  }

  @override
  void didUpdateWidget(covariant _PurchaseItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.item;
    final current = widget.item;
    if (old.purchasedQuantity != current.purchasedQuantity && int.tryParse(_purchasedController.text) != current.purchasedQuantity) {
      _replace(_purchasedController, '${current.purchasedQuantity}');
    }
    if (old.bonusQuantity != current.bonusQuantity && int.tryParse(_bonusController.text) != current.bonusQuantity) {
      _replace(_bonusController, '${current.bonusQuantity}');
    }
    if (old.unitCost != current.unitCost && _number(_costController) != current.unitCost) {
      _replace(_costController, _display(current.unitCost));
    }
    if (old.discount != current.discount && _number(_discountController) != current.discount) {
      _replace(_discountController, _display(current.discount));
    }
    if (old.salePrice != current.salePrice && _number(_saleController) != current.salePrice) {
      _replace(_saleController, _display(current.salePrice));
    }
  }

  void _replace(TextEditingController controller, String value) {
    controller.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
  }

  int _integer(TextEditingController controller) => int.tryParse(controller.text.trim()) ?? 0;
  double _number(TextEditingController controller) => double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;

  void _emit() {
    widget.onChanged(widget.item.copyWith(
      purchasedQuantity: _integer(_purchasedController).clamp(0, 1 << 30).toInt(),
      bonusQuantity: _integer(_bonusController).clamp(0, 1 << 30).toInt(),
      unitCost: _number(_costController).clamp(0, double.infinity).toDouble(),
      discount: _number(_discountController).clamp(0, double.infinity).toDouble(),
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
    _costController.dispose();
    _discountController.dispose();
    _saleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 9, 11),
      decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _image(item.product.imageData),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              _currentPrices(item.product),
            ])),
            IconButton(tooltip: 'Eliminar', onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline, size: 20)),
          ]),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              Row(children: [
                Expanded(child: _quantityField(_purchasedController, 'Compradas', Icons.shopping_cart_outlined)),
                const SizedBox(width: 7),
                Expanded(child: _quantityField(_bonusController, 'Bonificadas', Icons.card_giftcard_outlined)),
                const SizedBox(width: 7),
                Expanded(child: _readonly('Recibidas', '${item.received}', Icons.inventory_2_outlined)),
                const SizedBox(width: 7),
                Expanded(child: _numberField(_costController, 'Costo unitario', Icons.attach_money)),
                const SizedBox(width: 7),
                Expanded(child: _numberField(_discountController, 'Descuento', Icons.discount_outlined, suffix: '\$ / %')),
                const SizedBox(width: 7),
                Expanded(child: _readonly('Total', widget.money(item.totalCost), Icons.calculate_outlined, color: AppColors.primary)),
              ]),
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(9)),
                child: Row(children: [
                  const Icon(Icons.sell_outlined, size: 17, color: AppColors.primary),
                  const SizedBox(width: 7),
                  const Text('Cambiar precio de venta', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('Actual ${widget.money(item.product.price)}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  SizedBox(width: 125, child: _numberField(_saleController, 'Nuevo precio', Icons.edit_outlined)),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _currentPrices(Product product) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Costo ${widget.money(product.cost)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        Text('Venta ${widget.money(product.price)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _image(String data) {
    final bytes = _decode(data);
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: bytes == null ? const Icon(Icons.image_outlined, size: 21, color: AppColors.textMuted) : Image.memory(bytes, fit: BoxFit.contain),
    );
  }

  Uint8List? _decode(String value) {
    if (value.trim().isEmpty) return null;
    try { return base64Decode(value.contains(',') ? value.split(',').last : value); } catch (_) { return null; }
  }

  Widget _numberField(TextEditingController controller, String label, IconData icon, {String? suffix}) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 17),
        suffixText: suffix,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      onChanged: (_) => _emit(),
    );
  }

  Widget _quantityField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 17),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(visualDensity: VisualDensity.compact, tooltip: 'Disminuir', onPressed: () => _step(controller, -1), icon: const Icon(Icons.remove, size: 16)),
            IconButton(visualDensity: VisualDensity.compact, tooltip: 'Aumentar', onPressed: () => _step(controller, 1), icon: const Icon(Icons.add, size: 16)),
          ],
        ),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      onChanged: (_) => _emit(),
    );
  }

  Widget _readonly(String label, String value, IconData icon, {Color? color}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 17),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: AppColors.inputBackground,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _CostChange {
  final Product product;
  final double newCost;
  const _CostChange(this.product, this.newCost);
}

class _CostDecision {
  final bool updateCost;
  final bool skipFuture;
  const _CostDecision({required this.updateCost, required this.skipFuture});
}

class _CostChangesDialog extends StatefulWidget {
  final List<_CostChange> changes;
  const _CostChangesDialog(this.changes);

  @override
  State<_CostChangesDialog> createState() => _CostChangesDialogState();
}

class _CostChangesDialogState extends State<_CostChangesDialog> {
  final _resolved = <String>{};
  final _skipFuture = <String, bool>{};
  final _decisions = <String, _CostDecision>{};

  void _resolve(_CostChange change, bool update) {
    final id = change.product.id;
    _resolved.add(id);
    _decisions[id] = _CostDecision(
      updateCost: update,
      skipFuture: _skipFuture[id] ?? false,
    );
    if (_resolved.length == widget.changes.length) {
      Navigator.pop(context, _decisions);
    } else {
      setState(() {});
    }
  }

  void _skipAll() {
    for (final change in widget.changes) {
      _decisions[change.product.id] = _CostDecision(
        updateCost: false,
        skipFuture: _skipFuture[change.product.id] ?? false,
      );
    }
    Navigator.pop(context, _decisions);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 10),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Actualizar costos', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 4),
                  Text('Estos ${widget.changes.length} productos tienen un costo diferente al registrado.', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ])),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: widget.changes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _costCard(widget.changes[index]),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(18, 5, 18, 16), child: Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _skipAll, child: const Text('Saltar todos')))),
          ],
        ),
      ),
    );
  }

  Widget _costCard(_CostChange change) {
    final done = _resolved.contains(change.product.id);
    final bytes = _decode(change.product.imageData);

    return Opacity(
      opacity: done ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                child: bytes == null ? const Icon(Icons.image_outlined, color: AppColors.textMuted) : Image.memory(bytes, fit: BoxFit.contain),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(change.product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
              if (done) const Icon(Icons.check_circle_outline, color: AppColors.successGreen),
            ]),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(9)),
              child: Row(children: [
                Expanded(child: _price('Actual', change.product.cost)),
                const Icon(Icons.arrow_forward_outlined, size: 20, color: AppColors.textMuted),
                Expanded(child: _price('Nuevo', change.newCost, color: AppColors.successGreen)),
              ]),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.primary.withAlpha(70)),
              ),
              child: const Text(
                'El nuevo costo reemplazará al anterior.',
                style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: done ? null : () => _resolve(change, true),
                  icon: const Icon(Icons.check, size: 17),
                  label: Text('Registrar ${change.newCost.toStringAsFixed(2)} como costo'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: OutlinedButton.icon(
                  onPressed: done ? null : () => _resolve(change, false),
                  icon: const Icon(Icons.close, size: 17),
                  label: const Text('Saltar'),
                ),
              ),
            ]),
            CheckboxListTile(
              value: _skipFuture[change.product.id] ?? false,
              onChanged: done ? null : (value) => setState(() => _skipFuture[change.product.id] = value ?? false),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('No volver a preguntarme para este producto', style: TextStyle(fontSize: 10)),
              subtitle: const Text('Solo durante este registro de compra.', style: TextStyle(fontSize: 8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _price(String label, double value, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      );

  Uint8List? _decode(String value) {
    if (value.trim().isEmpty) return null;
    try { return base64Decode(value.contains(',') ? value.split(',').last : value); } catch (_) { return null; }
  }
}
