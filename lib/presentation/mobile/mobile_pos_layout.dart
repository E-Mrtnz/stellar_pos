import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/utils/product_filter_utils.dart';
import 'package:stellar_pos/core/utils/product_utils.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/electronic_balance_sale_dialog.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/product_card.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sales_summary_with_keypad.dart';
import 'package:stellar_pos/presentation/widgets/product_filter_bar.dart';
import 'package:stellar_pos/presentation/widgets/product_image.dart';
import 'package:stellar_pos/presentation/widgets/product_search_bar.dart';

class MobilePosLayout extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final bool isLoading;
  final Map<String, int> cartQuantities;
  final Set<String> preparedProductIds;
  final List<String> tags;
  final int selectedTagIndex;
  final ValueChanged<int> onTagSelected;
  final String? selectedFilter;
  final ValueChanged<String?> onFilterChanged;
  final ValueChanged<String> onAddToCart;
  final ValueChanged<String> onRemoveFromCart;
  final void Function(String, bool)? onPreparedChanged;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final List<ElectronicBalanceCartItem> electronicBalanceSelection;
  final double total;
  final VoidCallback onCreateSale;
  final VoidCallback onMenu;
  final ValueChanged<String> onBarcodeDetected;
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
  final double change;
  final ValueChanged<String> onDecrementQuantity;
  final void Function(String, int) onQuantityChanged;
  final ValueChanged<String> onRemoveCartItem;
  final VoidCallback onClearCart;
  final String ticketNumber;

  const MobilePosLayout({
    super.key,
    required this.products,
    required this.isLoading,
    required this.cartQuantities,
    required this.preparedProductIds,
    required this.tags,
    required this.selectedTagIndex,
    required this.onTagSelected,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.electronicBalanceSelection,
    required this.total,
    required this.onCreateSale,
    required this.onMenu,
    required this.onBarcodeDetected,
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
    required this.change,
    required this.onDecrementQuantity,
    required this.onQuantityChanged,
    required this.onRemoveCartItem,
    required this.onClearCart,
    required this.ticketNumber,
    this.onPreparedChanged,
    this.onSearchChanged,
    this.searchQuery = '',
  });

  @override
  State<MobilePosLayout> createState() => _MobilePosLayoutState();
}

class _MobilePosLayoutState extends State<MobilePosLayout> {
  bool _listView = false;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant MobilePosLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _search.text) {
      _search.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _products {
    final result = ProductFilterUtils.apply(
      products: widget.products,
      searchQuery: widget.searchQuery,
      selectedFilter: widget.selectedFilter,
      tags: widget.tags,
      selectedTagIndex: widget.selectedTagIndex,
    );
    return List<Map<String, dynamic>>.from(result)
      ..sort((a, b) => ProductUtils.asString(a['name'])
          .toLowerCase()
          .compareTo(ProductUtils.asString(b['name']).toLowerCase()));
  }

  void _checkout() {
    if (widget.cartQuantities.isEmpty &&
        widget.electronicBalanceSelection.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto a la venta.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Container(
        height: MediaQuery.sizeOf(context).height * .94,
        decoration: const BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Detalle de venta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheet),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SalesSummaryWithKeypad(
                  cartQuantities: widget.cartQuantities,
                  preparedProductIds: widget.preparedProductIds,
                  products: widget.products,
                  selectedPaymentMethod: widget.selectedPaymentMethod,
                  onPaymentMethodChanged: widget.onPaymentMethodChanged,
                  selectedDebtor: widget.selectedDebtor,
                  debtorsList: widget.debtorsList,
                  onDebtorChanged: widget.onDebtorChanged,
                  discountAmountController: widget.discountAmountController,
                  discountPercentController: widget.discountPercentController,
                  cashReceivedController: widget.cashReceivedController,
                  onDiscountAmountChanged: widget.onDiscountAmountChanged,
                  onDiscountPercentChanged: widget.onDiscountPercentChanged,
                  onCashReceivedChanged: widget.onCashReceivedChanged,
                  subtotal: widget.subtotal,
                  cardFeeAmount: widget.cardFeeAmount,
                  total: widget.total,
                  change: widget.change,
                  onAddToCart: widget.onAddToCart,
                  onDecrementQuantity: widget.onDecrementQuantity,
                  onQuantityChanged: widget.onQuantityChanged,
                  onRemoveFromCart: widget.onRemoveCartItem,
                  onClearCart: widget.onClearCart,
                  onCreateSale: () {
                    Navigator.pop(sheet);
                    widget.onCreateSale();
                  },
                  ticketNumber: widget.ticketNumber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scanner() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MobileBarcodeScannerView(
          products: widget.products,
          cartQuantities: widget.cartQuantities,
          total: widget.total,
          onBarcodeDetected: widget.onBarcodeDetected,
          onCreateSale: _checkout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onMenu,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
              ),
              const Expanded(
                child: Text(
                  'Ventas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onMenu,
                icon: const Icon(Icons.menu_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: ProductSearchBar(
                  controller: _search,
                  onChanged: widget.onSearchChanged ?? (_) {},
                ),
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: Icons.qr_code_scanner_rounded,
                onTap: _scanner,
              ),
              const SizedBox(width: 6),
              _ActionButton(
                icon: _listView
                    ? Icons.grid_view_rounded
                    : Icons.view_list_rounded,
                onTap: () => setState(() => _listView = !_listView),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: ProductFilterBar(
            tags: widget.tags,
            selectedFilter: widget.selectedFilter,
            onFilterChanged: widget.onFilterChanged,
            selectedTagIndex: widget.selectedTagIndex,
            onTagSelected: widget.onTagSelected,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: widget.isLoading && widget.products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _listView
                  ? _MobileProductList(
                      products: products,
                      cartQuantities: widget.cartQuantities,
                      onAdd: widget.onAddToCart,
                      onRemove: widget.onRemoveFromCart,
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 94),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: .72,
                      ),
                      itemCount: products.length,
                      itemBuilder: (_, index) {
                        final product = products[index];
                        final id = product['id'].toString();
                        return ProductCard(
                          product: product,
                          quantityInCart: widget.cartQuantities[id] ?? 0,
                          preparedSelected:
                              widget.preparedProductIds.contains(id),
                          onAdd: () => widget.onAddToCart(id),
                          onRemove: () => widget.onRemoveFromCart(id),
                          onPreparedChanged: (value) =>
                              widget.onPreparedChanged?.call(id, value),
                        );
                      },
                    ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (widget.cartQuantities.isEmpty &&
                      widget.electronicBalanceSelection.isEmpty)
                  ? null
                  : _checkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Crear venta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '\$' + widget.total.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.primary),
      style: IconButton.styleFrom(
        fixedSize: const Size(46, 46),
        backgroundColor: AppColors.cardBackground,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _MobileProductList extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Map<String, int> cartQuantities;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const _MobileProductList({
    required this.products,
    required this.cartQuantities,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 94),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final product = products[index];
        final id = product['id'].toString();
        final quantity = cartQuantities[id] ?? 0;
        return Material(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => onAdd(id),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ProductImage(
                    productId: id,
                    imageData: product['imageData']?.toString() ?? '',
                    width: 58,
                    height: 58,
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.circular(10),
                    placeholderIcon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ProductUtils.cleanName(product),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(ProductUtils.unit(product)),
                        const SizedBox(height: 3),
                        Text(
                          ProductUtils.money(ProductUtils.price(product)),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (quantity > 0)
                    IconButton(
                      onPressed: () => onRemove(id),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.dangerRed,
                      ),
                    ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: quantity > 0
                        ? AppColors.primary
                        : AppColors.border,
                    child: quantity > 0
                        ? Text(
                            quantity.toString(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MobileBarcodeScannerView extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Map<String, int> cartQuantities;
  final double total;
  final ValueChanged<String> onBarcodeDetected;
  final VoidCallback onCreateSale;

  const MobileBarcodeScannerView({
    super.key,
    required this.products,
    required this.cartQuantities,
    required this.total,
    required this.onBarcodeDetected,
    required this.onCreateSale,
  });

  @override
  State<MobileBarcodeScannerView> createState() =>
      _MobileBarcodeScannerViewState();
}

class _MobileBarcodeScannerViewState extends State<MobileBarcodeScannerView> {
  late final MobileScannerController _controller;
  String? _lastCode;
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 700,
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _detect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      final now = DateTime.now();
      if (_lastCode == value &&
          _lastScanAt != null &&
          now.difference(_lastScanAt!) < const Duration(milliseconds: 700)) {
        continue;
      }
      _lastCode = value;
      _lastScanAt = now;
      widget.onBarcodeDetected(value);
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.cartQuantities.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final selected = widget.products.where((product) {
      return (widget.cartQuantities[product['id'].toString()] ?? 0) > 0;
    }).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.inputBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'Escanear producto',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _controller.toggleTorch,
                    icon: const Icon(Icons.flashlight_on_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _detect,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'Productos escaneados: ' + count.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: selected.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          'Acerca el código de barras a la cámara para agregar productos.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: selected.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final product = selected[index];
                        final id = product['id'].toString();
                        final quantity = widget.cartQuantities[id] ?? 0;
                        return Material(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            leading: ProductImage(
                              productId: id,
                              imageData:
                                  product['imageData']?.toString() ?? '',
                              width: 50,
                              height: 50,
                              fit: BoxFit.contain,
                              borderRadius: BorderRadius.circular(8),
                              placeholderIcon: Icons.inventory_2_outlined,
                            ),
                            title: Text(ProductUtils.cleanName(product)),
                            subtitle: Text(
                              ProductUtils.money(ProductUtils.price(product)) +
                                  ' × ' +
                                  quantity.toString(),
                            ),
                            trailing: Text(
                              ProductUtils.money(
                                ProductUtils.price(product) * quantity,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: count == 0 ? null : widget.onCreateSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Crear venta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '\$' + widget.total.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
