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

  static Future<bool?> show(BuildContext context, {PurchaseRecord? purchase}) =>
      showDialog<bool>(
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
        ..addAll(purchase.items.map((record) {
          final product = provider.findById(record.productId) ??
              Product(
                id: record.productId,
                name: record.productName,
                unit: record.unit,
                department: '',
                brand: '',
                cost: record.previousCost ?? record.unitCost,
                price: record.previousSalePrice ?? record.salePrice,
                stock: 0,
                minStock: 0,
                maxStock: 0,
                category: '',
                barcode: record.barcode,
                imageData: record.imageData,
              );
          final presentationUnits = record.unitsPerPresentation <= 0
              ? 1
              : record.unitsPerPresentation;
          final originalPresentationPrice = record.unitCost * presentationUnits;
          final paidPresentations = record.quantity;
          final totalPaid = paidPresentations > 0 ? record.total / paidPresentations : 0;
          final ivaPerPresentation = record.iva ?? 0;
          final discountedPresentationPrice = totalPaid > 0
              ? totalPaid
              : (originalPresentationPrice *
                  (1 - (record.discountPercent ?? 0) / 100));
          final discountPercent = record.discountPercent ??
              (originalPresentationPrice > 0
                  ? ((originalPresentationPrice - discountedPresentationPrice) /
                          originalPresentationPrice) *
                      100
                  : 0);
          return _DraftPurchaseItem(
            product: product,
            purchasedQuantity: record.quantity,
            bonusQuantity: record.bonusQuantity,
            unitsPerPresentation: presentationUnits,
            originalPresentationPrice: originalPresentationPrice,
            discountedPresentationPrice: discountedPresentationPrice,
            discountPercent: discountPercent,
            ivaPerPresentation: ivaPerPresentation,
            salePrice: record.salePrice,
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
    if (!mounted || ModalRoute.of(context)?.isCurrent != true || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final enter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
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
    if (character == null || character.isEmpty || character.trim().isEmpty) {
      return KeyEventResult.ignored;
    }
    final now = DateTime.now();
    _scannerBuffer = _lastScannerKey == null ||
            now.difference(_lastScannerKey!) > _scannerTimeout
        ? character
        : _scannerBuffer + character;
    _lastScannerKey = now;
    return KeyEventResult.handled;
  }

  String _money(double value) => '\$${value.toStringAsFixed(2)}';
  String _dateText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  List<Product> _visibleProducts(ProductProvider provider) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return provider.products;
    return provider.products
        .where((p) => p.name.toLowerCase().contains(query) ||
            p.barcode.toLowerCase().contains(query) ||
            p.brand.toLowerCase().contains(query))
        .toList();
  }

  int _oldQuantity(String productId) {
    if (!_editing) return 0;
    for (final item in widget.purchase!.items) {
      if (item.productId == productId) return item.totalQuantity;
    }
    return 0;
  }

  int _baseStock(Product product) =>
      (product.stock - _oldQuantity(product.id)).clamp(0, 1 << 30).toInt();

  @override
  Widget build(BuildContext context) {
    final products = _visibleProducts(context.watch<ProductProvider>());
    final distributors = context.watch<ProvidersProvider>().distributors;
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 900),
        child: Column(
          children: [
            _header(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: _purchaseInfo(distributors),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Column(
                  children: [
                    _productPicker(products),
                    const SizedBox(height: 10),
                    _purchaseItems(),
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
        padding: const EdgeInsets.fromLTRB(18, 10, 10, 8),
        child: Row(
          children: [
            Icon(
              _editing ? Icons.edit_note_outlined : Icons.shopping_bag_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _editing ? 'Modificar compra' : 'Nueva compra',
                style: AppTextStyles.sectionTitle,
              ),
            ),
            if (_editing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text(
                  'MODIFICACIÓN',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            IconButton(
              onPressed: _saving ? null : _cancel,
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      );

  Widget _purchaseInfo(List<String> distributors) => Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: _distributor,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Distribuidora',
                prefixIcon: Icon(Icons.storefront_outlined, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: distributors
                  .map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ))
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                        _distributor = value;
                        _dirty = true;
                      }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _invoiceController,
              enabled: !_saving,
              onChanged: (_) => setState(() => _dirty = true),
              decoration: const InputDecoration(
                labelText: 'N.º de factura',
                prefixIcon: Icon(Icons.receipt_long_outlined, size: 18),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: _saving ? null : _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha',
                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: Text(_dateText(_date), style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.payments_outlined, size: 17, color: AppColors.successGreen),
                SizedBox(width: 6),
                Text('Contado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      );

  Widget _productPicker(List<Product> products) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 205, maxHeight: 275),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Agregar productos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  Text('${products.length} disponibles', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: products.isEmpty
                  ? const Center(child: Text('No hay productos registrados.', style: TextStyle(fontSize: 11)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(7),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 155,
                        mainAxisExtent: 82,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: products.length,
                      itemBuilder: (_, index) => _productCard(products[index]),
                    ),
            ),
          ],
        ),
      );

  Widget _productCard(Product product) {
    final bytes = _decode(product.imageData);
    return InkWell(
      onTap: _saving ? null : () => _addProduct(product),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: bytes == null
                  ? const Icon(Icons.inventory_2_outlined, size: 21, color: AppColors.textMuted)
                  : Image.memory(bytes, fit: BoxFit.contain),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Costo ${_money(product.cost)} · Stock ${product.stock}', style: const TextStyle(fontSize: 7, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addProduct(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);
    setState(() {
      _dirty = true;
      if (index >= 0) {
        _items[index] = _items[index].copyWith(
          purchasedQuantity: _items[index].purchasedQuantity + 1,
        );
      } else {
        _items.add(
          _DraftPurchaseItem(
            product: product,
            purchasedQuantity: 1,
            bonusQuantity: 0,
            unitsPerPresentation: 1,
            originalPresentationPrice: product.cost,
            discountedPresentationPrice: product.cost,
            discountPercent: 0,
            ivaPerPresentation: null,
            salePrice: product.price,
          ),
        );
      }
    });
  }

  Widget _purchaseItems() => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Productos de la compra', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  if (_items.isNotEmpty)
                    Text('$_received recibidas · $_bonuses bonificadas', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1),
            _items.isEmpty
                ? const SizedBox(
                    height: 125,
                    child: Center(child: Text('Selecciona productos de arriba', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(7),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, index) => _item(index),
                  ),
          ],
        ),
      );

  Widget _item(int index) {
    final item = _items[index];
    return _PurchaseItemCard(
      key: ValueKey(item.product.id),
      item: item,
      money: _money,
      baseStock: _baseStock(item.product),
      onChanged: (updated) => setState(() {
        _items[index] = updated;
        _dirty = true;
      }),
      onDelete: () => setState(() {
        _items.removeAt(index);
        _dirty = true;
      }),
    );
  }

  Widget _footer() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 9),
        child: Row(
          children: [
            if (_editing)
              OutlinedButton(
                onPressed: _saving ? null : _cancel,
                child: const Text('Cancelar', style: TextStyle(fontSize: 11)),
              ),
            const SizedBox(width: 12),
            _stat('Unidades recibidas', '$_received'),
            const SizedBox(width: 12),
            _stat('Bonificaciones', '$_bonuses', color: AppColors.successGreen),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('TOTAL PAGADO', style: TextStyle(fontSize: 8, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                Text(_money(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
              ],
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _saving || _items.isEmpty ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_editing ? Icons.save_outlined : Icons.check, size: 17),
              label: Text(_saving ? 'Guardando...' : (_editing ? 'Guardar cambios' : 'Guardar compra'), style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );

  Widget _stat(String label, String value, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textMuted)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked != null && mounted) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute, _date.second);
        _dirty = true;
      });
    }
  }

  Future<void> _cancel() async {
    if (!_editing || !_dirty) {
      Navigator.pop(context, false);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Cancelar modificación?'),
        content: const Text('Tienes cambios sin guardar. Si sales ahora, se perderán.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar salida')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir sin guardar')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context, false);
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
    for (final item in _items) {
      if (item.purchasedQuantity <= 0) continue;
      if (item.unitsPerPresentation <= 0) {
        _error('Las unidades por presentación deben ser mayores que cero en ${item.product.name}.');
        return;
      }
      if (item.originalPresentationPrice <= 0) {
        _error('Ingresa el precio sin descuento en ${item.product.name}.');
        return;
      }
      if (item.discountedPresentationPrice <= 0) {
        _error('El precio con descuento debe ser mayor que cero en ${item.product.name}.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final productProvider = context.read<ProductProvider>();
      final oldItems = _editing
          ? {for (final item in widget.purchase!.items) item.productId: item}
          : <String, PurchaseItemRecord>{};
      final costChanges = <_CostChange>[];
      final updatePriceIds = <String>{};

      for (final item in _items) {
        if (item.purchasedQuantity <= 0) continue;
        final current = productProvider.findById(item.product.id);
        if (current == null) continue;

        final old = oldItems[item.product.id];
        final unitCost = item.unitCost;
        if ((current.cost - unitCost).abs() > 0.0001) {
          final changedFromOriginal = !_editing || old == null || (old.unitCost - unitCost).abs() > 0.0001;
          if (changedFromOriginal) costChanges.add(_CostChange(current, unitCost));
        }

        if (!_editing || old == null || (old.salePrice - item.salePrice).abs() > 0.0001) {
          updatePriceIds.add(item.product.id);
        }
      }

      Set<String> updateCostIds = <String>{};
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
        updateCostIds = {
          for (final change in costChanges)
            if (decisions[change.product.id]?.updateCost == true) change.product.id,
        };
        if (!_editing) {
          for (final change in costChanges) {
            if (updateCostIds.contains(change.product.id)) {
              productProvider.updateProduct(change.product.copyWith(cost: change.newCost));
            }
          }
        }
      }

      final records = _items.map((item) {
        final old = oldItems[item.product.id];
        return PurchaseItemRecord(
          productId: item.product.id,
          productName: item.product.name,
          unit: item.product.unit,
          barcode: item.product.barcode,
          imageData: item.product.imageData,
          unitCost: item.unitCost,
          previousCost: old?.previousCost ?? item.product.cost,
          previousSalePrice: old?.previousSalePrice ?? item.product.price,
          quantity: item.purchasedQuantity,
          bonusQuantity: item.bonusQuantity,
          unitsPerPresentation: item.unitsPerPresentation,
          totalQuantity: item.received,
          salePrice: item.salePrice,
          discount: item.discountAmount,
          discountPercent: item.discountPercent > 0 ? item.discountPercent : null,
          iva: item.ivaPerPresentation,
          total: item.totalCost,
          effectiveUnitCost: item.unitCost,
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
        final ok = await context.read<PurchasesProvider>().updatePurchase(
          updated,
          productProvider,
          updateCostIds: updateCostIds,
          updatePriceIds: updatePriceIds,
        );
        if (!ok) throw StateError('La compra ya no existe.');
      } else {
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
        context.read<PurchasesProvider>().addPurchase(
          PurchaseRecord(
            id: IdGenerator.newId(),
            invoiceNumber: _invoiceController.text.trim(),
            distributorName: _distributor!.trim(),
            arrivalAt: DateTime(_date.year, _date.month, _date.day, DateTime.now().hour, DateTime.now().minute, DateTime.now().second),
            paymentMethod: 'Contado',
            items: records,
            subtotal: _items.fold(0, (sum, item) => sum + item.netSubtotal),
            discount: records.fold(0, (sum, item) => sum + item.discount),
            total: _total,
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _error('No se pudo guardar la compra: $error');
    }
  }

  void _error(String message) => AppAlert.show(
        context,
        message,
        title: 'No se puede continuar',
        type: AppAlertType.error,
      );

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
  final int unitsPerPresentation;
  final double originalPresentationPrice;
  final double discountedPresentationPrice;
  final double discountPercent;
  final double? ivaPerPresentation;
  final double salePrice;

  const _DraftPurchaseItem({
    required this.product,
    required this.purchasedQuantity,
    required this.bonusQuantity,
    required this.unitsPerPresentation,
    required this.originalPresentationPrice,
    required this.discountedPresentationPrice,
    required this.discountPercent,
    required this.ivaPerPresentation,
    required this.salePrice,
  });

  int get received => purchasedQuantity * unitsPerPresentation + bonusQuantity;

  double get discountAmountPerPresentation =>
      (originalPresentationPrice - discountedPresentationPrice).clamp(0, double.infinity).toDouble();

  double get discountAmount => discountAmountPerPresentation * purchasedQuantity;

  double get totalCost => discountedPresentationPrice * purchasedQuantity;

  double get netSubtotal =>
      (discountedPresentationPrice - (ivaPerPresentation ?? 0)).clamp(0, double.infinity).toDouble() * purchasedQuantity;

  double get unitCost =>
      unitsPerPresentation <= 0 ? 0 : originalPresentationPrice / unitsPerPresentation;

  _DraftPurchaseItem copyWith({
    int? purchasedQuantity,
    int? bonusQuantity,
    int? unitsPerPresentation,
    double? originalPresentationPrice,
    double? discountedPresentationPrice,
    double? discountPercent,
    double? ivaPerPresentation,
    bool clearIva = false,
    double? salePrice,
  }) =>
      _DraftPurchaseItem(
        product: product,
        purchasedQuantity: purchasedQuantity ?? this.purchasedQuantity,
        bonusQuantity: bonusQuantity ?? this.bonusQuantity,
        unitsPerPresentation: unitsPerPresentation ?? this.unitsPerPresentation,
        originalPresentationPrice: originalPresentationPrice ?? this.originalPresentationPrice,
        discountedPresentationPrice: discountedPresentationPrice ?? this.discountedPresentationPrice,
        discountPercent: discountPercent ?? this.discountPercent,
        ivaPerPresentation: clearIva ? null : (ivaPerPresentation ?? this.ivaPerPresentation),
        salePrice: salePrice ?? this.salePrice,
      );
}

class _PurchaseItemCard extends StatefulWidget {
  final _DraftPurchaseItem item;
  final String Function(double) money;
  final int baseStock;
  final ValueChanged<_DraftPurchaseItem> onChanged;
  final VoidCallback onDelete;

  const _PurchaseItemCard({
    super.key,
    required this.item,
    required this.money,
    required this.baseStock,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_PurchaseItemCard> createState() => _PurchaseItemCardState();
}

class _PurchaseItemCardState extends State<_PurchaseItemCard> {
  late final TextEditingController _purchasedController;
  late final TextEditingController _bonusController;
  late final TextEditingController _presentationController;
  late final TextEditingController _originalController;
  late final TextEditingController _discountController;
  late final TextEditingController _ivaController;
  late final TextEditingController _saleController;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _purchasedController = TextEditingController(text: '${item.purchasedQuantity}');
    _bonusController = TextEditingController(text: '${item.bonusQuantity}');
    _presentationController = TextEditingController(text: '${item.unitsPerPresentation}');
    _originalController = TextEditingController(text: item.originalPresentationPrice.toStringAsFixed(2));
    _discountController = TextEditingController(text: item.discountPercent > 0 ? item.discountPercent.toStringAsFixed(2) : '');
    _ivaController = TextEditingController(text: item.ivaPerPresentation?.toStringAsFixed(2) ?? '');
    _saleController = TextEditingController(text: item.salePrice.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(covariant _PurchaseItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.item;
    final current = widget.item;
    if (old.purchasedQuantity != current.purchasedQuantity) _replace(_purchasedController, '${current.purchasedQuantity}');
    if (old.bonusQuantity != current.bonusQuantity) _replace(_bonusController, '${current.bonusQuantity}');
    if (old.unitsPerPresentation != current.unitsPerPresentation) _replace(_presentationController, '${current.unitsPerPresentation}');
    if ((old.originalPresentationPrice - current.originalPresentationPrice).abs() > 0.0001) _replace(_originalController, current.originalPresentationPrice.toStringAsFixed(2));
    if ((old.discountPercent - current.discountPercent).abs() > 0.0001) _replace(_discountController, current.discountPercent > 0 ? current.discountPercent.toStringAsFixed(2) : '');
    if (old.ivaPerPresentation != current.ivaPerPresentation) _replace(_ivaController, current.ivaPerPresentation?.toStringAsFixed(2) ?? '');
    if ((old.salePrice - current.salePrice).abs() > 0.0001) _replace(_saleController, current.salePrice.toStringAsFixed(2));
  }

  void _replace(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  int _integer(TextEditingController controller) => int.tryParse(controller.text.trim()) ?? 0;
  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
  double? _numberOrNull(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  void _recalculateFromOriginal() {
    if (_updating) return;
    final original = _number(_originalController);
    final discount = _number(_discountController).clamp(0, 100).toDouble();
    if (original <= 0) return;
    _updating = true;
    final discounted = original * (1 - discount / 100);
    _updating = false;
    widget.onChanged(widget.item.copyWith(
      originalPresentationPrice: original,
      discountedPresentationPrice: discounted,
      discountPercent: discount,
    ));
  }

  void _recalculateFromDiscount() {
    if (_updating) return;
    final discount = _number(_discountController).clamp(0, 100).toDouble();
    final original = _number(_originalController);
    if (original <= 0) return;
    _updating = true;
    final discounted = original * (1 - discount / 100);
    _updating = false;
    widget.onChanged(widget.item.copyWith(
      discountedPresentationPrice: discounted,
      discountPercent: discount,
    ));
  }

  void _emit({bool recalculateDiscount = false}) {
    if (_updating) return;
    final original = _number(_originalController);
    final discount = _number(_discountController).clamp(0, 100).toDouble();
    final discounted = recalculateDiscount
        ? original * (1 - discount / 100)
        : widget.item.discountedPresentationPrice;
    widget.onChanged(
      widget.item.copyWith(
        purchasedQuantity: _integer(_purchasedController).clamp(0, 1 << 30).toInt(),
        bonusQuantity: _integer(_bonusController).clamp(0, 1 << 30).toInt(),
        unitsPerPresentation: _integer(_presentationController).clamp(1, 1 << 30).toInt(),
        originalPresentationPrice: original,
        discountedPresentationPrice: discounted,
        discountPercent: discount,
        ivaPerPresentation: _numberOrNull(_ivaController),
        salePrice: _number(_saleController).clamp(0, double.infinity).toDouble(),
      ),
    );
  }

  void _step(TextEditingController controller, int delta) {
    controller.text = (_integer(controller) + delta).clamp(0, 1 << 30).toInt().toString();
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    _emit(recalculateDiscount: controller == _presentationController ? false : false);
  }

  @override
  void dispose() {
    _purchasedController.dispose();
    _bonusController.dispose();
    _presentationController.dispose();
    _originalController.dispose();
    _discountController.dispose();
    _ivaController.dispose();
    _saleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _image(item.product.imageData),
          const SizedBox(width: 8),
          SizedBox(
            width: 155,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                _currentPrices(item.product),
                const SizedBox(height: 3),
                Text('Stock ${widget.baseStock} → ${widget.baseStock + item.received}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.successGreen)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _quantityField(_purchasedController, 'Compradas', Icons.shopping_cart_outlined)),
                const SizedBox(width: 4),
                Expanded(child: _quantityField(_bonusController, 'Bonificadas', Icons.card_giftcard_outlined)),
                const SizedBox(width: 4),
                Expanded(child: _quantityField(_presentationController, 'Unid./present.', Icons.inventory_2_outlined)),
                const SizedBox(width: 4),
                Expanded(child: _readonly('Recibidas', '${item.received}', Icons.check_box_outlined)),
                const SizedBox(width: 4),
                Expanded(child: _editablePrice(_originalController, 'Sin descuento', Icons.sell_outlined, onChanged: _recalculateFromOriginal)),
                const SizedBox(width: 4),
                Expanded(child: _numberField(_discountController, 'Desc. %', Icons.discount_outlined, onChanged: _recalculateFromDiscount)),
                const SizedBox(width: 4),
                Expanded(child: _readonly('Con descuento', widget.money(item.discountedPresentationPrice), Icons.local_offer_outlined, color: AppColors.primary, filled: true)),
                const SizedBox(width: 4),
                Expanded(child: _numberField(_ivaController, 'IVA \$', Icons.receipt_long_outlined, onChanged: _emit, hint: '—')),
                const SizedBox(width: 4),
                Expanded(child: _readonly('Costo unitario', widget.money(item.unitCost), Icons.calculate_outlined, color: AppColors.successGreen, filled: true)),
                const SizedBox(width: 4),
                Expanded(child: _numberField(_saleController, 'Nuevo precio', Icons.edit_outlined, onChanged: _emit)),
              ],
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: widget.onDelete,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _fieldBox(String label, IconData icon, Widget child, {Color? color, bool editable = true}) => Container(
        height: 48,
        padding: const EdgeInsets.fromLTRB(5, 4, 5, 3),
        decoration: BoxDecoration(
          color: color ?? AppColors.inputBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: editable ? AppColors.border : AppColors.primary.withAlpha(70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 7, color: editable ? AppColors.textSecondary : AppColors.primary, fontWeight: FontWeight.w700)),
                if (!editable) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.lock_outline, size: 8, color: AppColors.primary),
                ],
              ],
            ),
            const SizedBox(height: 1),
            Expanded(child: Row(children: [Icon(icon, size: 12, color: editable ? AppColors.textSecondary : AppColors.primary), const SizedBox(width: 2), Expanded(child: child)])),
          ],
        ),
      );

  Widget _editablePrice(TextEditingController controller, String label, IconData icon, {required VoidCallback onChanged}) =>
      _fieldBox(
        label,
        icon,
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          onChanged: (_) => onChanged(),
        ),
      );

  Widget _numberField(TextEditingController controller, String label, IconData icon, {required VoidCallback onChanged, String? hint}) =>
      _fieldBox(
        label,
        icon,
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          decoration: InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, hintText: hint),
          onChanged: (_) => onChanged(),
        ),
      );

  Widget _quantityField(TextEditingController controller, String label, IconData icon) =>
      _fieldBox(
        label,
        icon,
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                onChanged: (_) => _emit(),
              ),
            ),
            _stepButton(Icons.remove, 'Disminuir', () => _step(controller, -1)),
            _stepButton(Icons.add, 'Aumentar', () => _step(controller, 1)),
          ],
        ),
      );

  Widget _stepButton(IconData icon, String tooltip, VoidCallback onPressed) => SizedBox(
        width: 16,
        height: 22,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          iconSize: 11,
          icon: Icon(icon),
        ),
      );

  Widget _readonly(String label, String value, IconData icon, {Color? color, bool filled = false}) =>
      _fieldBox(
        label,
        icon,
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        color: filled ? (color ?? AppColors.primary).withAlpha(12) : null,
        editable: false,
      );

  Widget _currentPrices(Product product) => Row(
        children: [
          Text('C ${widget.money(product.cost)}', style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700)),
          const SizedBox(width: 7),
          Text('V ${widget.money(product.price)}', style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _image(String data) {
    final bytes = _decode(data);
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.border),
      ),
      child: bytes == null
          ? const Icon(Icons.image_outlined, size: 18, color: AppColors.textMuted)
          : Image.memory(bytes, fit: BoxFit.contain),
    );
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
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Icon(Icons.price_change_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Actualizar costos', style: AppTextStyles.sectionTitle),
                          Text('${widget.changes.length} productos tienen un costo diferente al registrado.', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: widget.changes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, index) => _costCard(widget.changes[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _skipAll,
                    icon: const Icon(Icons.skip_next_outlined, size: 16),
                    label: const Text('Saltar todos', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _costCard(_CostChange change) {
    final done = _resolved.contains(change.product.id);
    return Opacity(
      opacity: done ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(change.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                if (done) const Icon(Icons.check_circle_outline, color: AppColors.successGreen, size: 17),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(child: _price('Actual', change.product.cost)),
                const Icon(Icons.arrow_forward_outlined, size: 15, color: AppColors.textMuted),
                Expanded(child: _price('Nuevo', change.newCost, color: AppColors.successGreen)),
              ],
            ),
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), borderRadius: BorderRadius.circular(6)),
              child: const Text('El nuevo costo reemplazará al anterior.', style: TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: done ? null : () => _resolve(change, true),
                    icon: const Icon(Icons.check, size: 14),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 31), padding: const EdgeInsets.symmetric(horizontal: 6)),
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text('Registrar ${change.newCost.toStringAsFixed(2)} como costo')),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 88,
                  child: OutlinedButton.icon(
                    onPressed: done ? null : () => _resolve(change, false),
                    icon: const Icon(Icons.close, size: 14),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 31), padding: const EdgeInsets.symmetric(horizontal: 5)),
                    label: const Text('Saltar', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Row(
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Checkbox(
                    value: _skipFuture[change.product.id] ?? false,
                    onChanged: done ? null : (value) => setState(() => _skipFuture[change.product.id] = value ?? false),
                  ),
                ),
                const SizedBox(width: 3),
                const Expanded(child: Text('No volver a preguntarme para este producto', style: TextStyle(fontSize: 8))),
                const Text('Solo esta compra', style: TextStyle(fontSize: 7, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _price(String label, double value, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 7, color: AppColors.textMuted)),
          Text('\$${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ],
      );
}
