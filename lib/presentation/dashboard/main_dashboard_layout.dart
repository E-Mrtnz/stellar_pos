import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/debt_provider.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';
import 'package:stellar_pos/core/providers/printer_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/presentation/Inventory/inventory_layout.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/central_product_grid.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/electronic_balance_management_dialog.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/electronic_balance_sale_dialog.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sale_detail_dialog.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sale_success_dialog.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sales_summary_with_keypad.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sidebar_drawer.dart';
import 'package:stellar_pos/presentation/debts/debts_layout.dart';
import 'package:stellar_pos/presentation/sales/sales_layout.dart';
import 'package:stellar_pos/presentation/providers/providers_layout.dart';
import 'package:stellar_pos/presentation/purchases/purchases_layout.dart';
import 'package:stellar_pos/presentation/settings/printer_settings_layout.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';

class MainDashboardLayout extends StatefulWidget {
  const MainDashboardLayout({super.key});
  @override
  State<MainDashboardLayout> createState() =>
      _MainDashboardLayoutState();
}

class _MainDashboardLayoutState extends State<MainDashboardLayout> {
  int _selectedNavIndex = AppNavigation.home;
  int _selectedTagIndex = 0;
  String? _selectedFilter;
  String _searchQuery = '';
  bool _isSidebarExpanded = true;
  final Map<String, int> _cartQuantities = {};
  List<ElectronicBalanceCartItem> _electronicBalanceSelection = [];
  String _barcodeBuffer = '';
  DateTime? _lastBarcodeInputAt;
  OverlayEntry? _productNotFoundOverlay;
  Timer? _productNotFoundTimer;
  int _selectedPaymentMethod = AppPaymentMethods.cash;
  String? _selectedDebtor;
  SaleRecord? _editingSale;
  final TextEditingController _discountAmountController =
      TextEditingController();
  final TextEditingController _discountPercentController =
      TextEditingController();
  final TextEditingController _cashReceivedController =
      TextEditingController();
  List<String> get _tags => context.watch<CatalogProvider>().tags;
  List<String> get _debtors => context
      .watch<CatalogProvider>()
      .clients
      .map((client) => client.name)
      .toList();
  @override
  void initState() {
    super.initState();
    SaleDetailDialog.editHandler = _startEditingSale;
  }

  @override
  void dispose() {
    SaleDetailDialog.editHandler = null;
    _productNotFoundTimer?.cancel();
    _productNotFoundOverlay?.remove();
    _discountAmountController.dispose();
    _discountPercentController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  KeyEventResult _handleBarcodeKey(FocusNode node, KeyEvent event) {
    if (_selectedNavIndex != AppNavigation.home ||
        event is! KeyDownEvent)
      return KeyEventResult.ignored;
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (isEnter) {
      final barcode = _barcodeBuffer.trim();
      _barcodeBuffer = '';
      _lastBarcodeInputAt = null;
      if (barcode.isNotEmpty) {
        _handleScannedBarcode(barcode);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final character = event.character;
    if (character == null ||
        character.isEmpty ||
        character.trim().isEmpty)
      return KeyEventResult.ignored;
    final now = DateTime.now();
    final elapsed = _lastBarcodeInputAt == null
        ? null
        : now.difference(_lastBarcodeInputAt!).inMilliseconds;
    if (elapsed != null && elapsed > 200) _barcodeBuffer = '';
    _barcodeBuffer += character;
    _lastBarcodeInputAt = now;
    return KeyEventResult.ignored;
  }

  void _handleScannedBarcode(String barcode) {
    final product = context.read<ProductProvider>().findByBarcode(
      barcode,
    );
    if (product != null) {
      _addToCart(product.id);
      return;
    }
    _showProductNotFoundAlert();
  }

  void _showProductNotFoundAlert() {
    if (!mounted) return;
    _productNotFoundTimer?.cancel();
    _productNotFoundOverlay?.remove();
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.of(overlayContext).padding.top + 18,
        left: 20,
        right: 20,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: const _ProductNotFoundAlert(),
              ),
            ),
          ),
        ),
      ),
    );
    _productNotFoundOverlay = entry;
    overlay.insert(entry);
    _productNotFoundTimer = Timer(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
      if (identical(_productNotFoundOverlay, entry))
        _productNotFoundOverlay = null;
    });
  }

  void _addToCart(String productId) {
    final product = context.read<ProductProvider>().findById(productId);
    if (product == null) return;
    setState(
      () => _cartQuantities[productId] =
          (_cartQuantities[productId] ?? 0) + 1,
    );
  }

  void _setCartQuantity(String productId, int quantity) {
    if (_isElectronicBalanceKey(productId)) {
      _setElectronicQuantity(productId, quantity);
      return;
    }
    if (quantity <= 0) return;
    setState(() => _cartQuantities[productId] = quantity);
  }

  void _decrementQuantity(String productId) {
    if (_isElectronicBalanceKey(productId)) {
      final index = _electronicBalanceSelection.indexWhere(
        (item) => item.key == productId,
      );
      if (index < 0) return;
      final item = _electronicBalanceSelection[index];
      if (item.quantity <= 1)
        _removeElectronicItem(productId);
      else
        _setElectronicQuantity(productId, item.quantity - 1);
      return;
    }
    setState(() {
      final quantity = _cartQuantities[productId];
      if (quantity == null) return;
      if (quantity > 1)
        _cartQuantities[productId] = quantity - 1;
      else
        _cartQuantities.remove(productId);
    });
  }

  void _removeFromCart(String productId) {
    if (_isElectronicBalanceKey(productId)) {
      _removeElectronicItem(productId);
      return;
    }
    setState(() => _cartQuantities.remove(productId));
  }

  void _clearCart() {
    setState(() {
      _cartQuantities.clear();
      _electronicBalanceSelection = [];
      _discountAmountController.clear();
      _discountPercentController.clear();
      _cashReceivedController.clear();
      _selectedDebtor = null;
    });
  }

  bool _isElectronicBalanceKey(String id) =>
      id.startsWith('electronic:') ||
      _electronicBalanceSelection.any((item) => item.key == id);
  void _setElectronicQuantity(String key, int quantity) {
    final index = _electronicBalanceSelection.indexWhere(
      (item) => item.key == key,
    );
    if (index < 0) return;
    if (quantity <= 0) {
      _removeElectronicItem(key);
      return;
    }
    setState(
      () => _electronicBalanceSelection[index] =
          _electronicBalanceSelection[index].copyWith(
            quantity: quantity,
          ),
    );
  }

  void _removeElectronicItem(String key) {
    setState(
      () => _electronicBalanceSelection = _electronicBalanceSelection
          .where((item) => item.key != key)
          .toList(),
    );
  }

  Map<String, int> get _combinedCartQuantities {
    final result = Map<String, int>.from(_cartQuantities);
    for (final item in _electronicBalanceSelection)
      result[item.key] = item.quantity;
    return result;
  }

  List<Map<String, dynamic>> get _salesCatalog {
    final products = List<Map<String, dynamic>>.from(
      context.read<ProductProvider>().productMaps,
    );
    for (final item in _electronicBalanceSelection)
      products.add({
        'id': item.key,
        'name': '${item.companyName} · ${item.category}',
        'unit': 'Recarga',
        'price': item.amount,
        'imageData': '',
      });
    return products;
  }

  double get _subtotal {
    final provider = context.read<ProductProvider>();
    double total = 0;
    for (final entry in _cartQuantities.entries) {
      final product = provider.findById(entry.key);
      if (product != null)
        total += product.priceForQuantity(entry.value);
    }
    for (final item in _electronicBalanceSelection)
      total += item.amount * item.quantity;
    return total;
  }

  double get _discountAmount =>
      double.tryParse(
        _discountAmountController.text.replaceAll(',', '.'),
      ) ??
      0;
  double get _discountPercent =>
      double.tryParse(
        _discountPercentController.text.replaceAll(',', '.'),
      ) ??
      0;
  double get _cardFeeAmount {
    if (_selectedPaymentMethod != AppPaymentMethods.card) return 0;
    final amount = _subtotal - _discountAmount;
    if (amount <= 0) return 0;
    return amount * AppInventory.cardFeePercentage;
  }

  double get _total {
    final total = _subtotal - _discountAmount + _cardFeeAmount;
    return total < 0 ? 0 : total;
  }

  double get _change {
    final cash =
        double.tryParse(
          _cashReceivedController.text.replaceAll(',', '.'),
        ) ??
        0;
    final change = cash - _total;
    return change > 0 ? change : 0;
  }

  void _onDiscountPercentChanged(String value) {
    final percent = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    final amount = _subtotal * percent / 100;
    _discountAmountController.text = amount > 0
        ? amount.toStringAsFixed(2)
        : '';
    setState(() {});
  }

  void _onDiscountAmountChanged(String value) {
    final amount = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    final percent = _subtotal <= 0 ? 0 : amount / _subtotal * 100;
    _discountPercentController.text = percent > 0
        ? percent.toStringAsFixed(2)
        : '';
    setState(() {});
  }

  String _paymentMethodLabel(int method) {
    switch (method) {
      case AppPaymentMethods.card:
        return AppStrings.cardPayment;
      case AppPaymentMethods.transfer:
        return AppStrings.transferPayment;
      case AppPaymentMethods.credit:
        return AppStrings.creditPayment;
      default:
        return AppStrings.cashPayment;
    }
  }

  int _paymentMethodIndex(String method) {
    if (method == AppStrings.cardPayment) return AppPaymentMethods.card;
    if (method == AppStrings.transferPayment)
      return AppPaymentMethods.transfer;
    if (method == AppStrings.creditPayment)
      return AppPaymentMethods.credit;
    return AppPaymentMethods.cash;
  }

  void _startEditingSale(SaleRecord sale) {
    final catalog = context.read<CatalogProvider>();
    final physical = <String, int>{};
    final electronic = <ElectronicBalanceCartItem>[];
    for (final item in sale.items) {
      if (item.isElectronicBalance) {
        final accountId = item.electronicBalanceAccountId;
        if (accountId == null) continue;
        final account = context
            .read<ElectronicBalanceProvider>()
            .findAccount(accountId);
        if (account == null) continue;
        electronic.add(
          ElectronicBalanceCartItem(
            accountId: accountId,
            companyName: account.companyName,
            category: item.electronicBalanceCategory ?? item.unit,
            amount: item.unitPrice,
            quantity: item.quantity,
          ),
        );
      } else
        physical[item.productId] =
            (physical[item.productId] ?? 0) + item.quantity;
    }
    setState(() {
      _editingSale = sale;
      _cartQuantities
        ..clear()
        ..addAll(physical);
      _electronicBalanceSelection = electronic;
      _selectedPaymentMethod = _paymentMethodIndex(sale.paymentMethod);
      _selectedDebtor = sale.clientId == null
          ? null
          : catalog.clients
                .where((client) => client.id == sale.clientId)
                .map((client) => client.name)
                .cast<String?>()
                .firstWhere(
                  (name) => name != null,
                  orElse: () => sale.clientName,
                );
      _discountAmountController.text = sale.discountAmount > 0
          ? sale.discountAmount.toStringAsFixed(2)
          : '';
      _discountPercentController.text = sale.discountPercent > 0
          ? sale.discountPercent.toStringAsFixed(2)
          : '';
      _cashReceivedController.text = sale.received > 0
          ? sale.received.toStringAsFixed(2)
          : '';
      _selectedNavIndex = AppNavigation.home;
    });
  }

  Future<void> _updateSale() async {
    final editing = _editingSale;
    if (editing == null) return;
    if (_cartQuantities.isEmpty &&
        _electronicBalanceSelection.isEmpty) {
      AppAlert.show(
        context,
        'Agrega al menos un producto o una recarga antes de actualizar la venta.',
        title: 'No se puede actualizar',
        type: AppAlertType.warning,
      );
      return;
    }
    if (_discountAmount < 0 || _discountAmount > _subtotal) {
      AppAlert.show(
        context,
        'El descuento no puede ser negativo ni superar el subtotal.',
        title: 'Descuento inválido',
        type: AppAlertType.warning,
      );
      return;
    }
    if (_selectedPaymentMethod == AppPaymentMethods.credit &&
        (_selectedDebtor == null || _selectedDebtor!.trim().isEmpty)) {
      AppAlert.show(
        context,
        'Selecciona un cliente para registrar una venta a crédito.',
        title: 'Cliente requerido',
        type: AppAlertType.warning,
      );
      return;
    }
    final catalog = context.read<CatalogProvider>();
    String? clientId;
    if (_selectedDebtor != null)
      for (final client in catalog.clients) {
        if (client.name == _selectedDebtor) {
          clientId = client.id;
          break;
        }
      }
    final received =
        double.tryParse(
          _cashReceivedController.text.replaceAll(',', '.'),
        ) ??
        0;
    final effectiveReceived =
        _selectedPaymentMethod == AppPaymentMethods.credit
        ? received.clamp(0, _total).toDouble()
        : (_selectedPaymentMethod == AppPaymentMethods.cash
              ? received
              : 0.0);
    try {
      final updated = context.read<SalesProvider>().updateSale(
        saleId: editing.id,
        updatedItems: [
          ..._cartQuantities.entries.map((entry) {
            final product = context.read<ProductProvider>().findById(
              entry.key,
            )!;
            return SaleItemRecord(
              productId: product.id,
              productName: product.name,
              unit: product.unit,
              brand: product.brand,
              barcode: product.barcode,
              cost: product.cost,
              unitPrice: product.price,
              quantity: entry.value,
              lineSubtotal: product.priceForQuantity(entry.value),
              discount: 0,
              lineTotal: product.priceForQuantity(entry.value),
              imageData: product.imageData,
            );
          }),
          ..._electronicBalanceSelection.map(
            (item) => SaleItemRecord(
              productId:
                  'electronic:${item.accountId}:${item.category}:${item.amount.toStringAsFixed(4)}',
              productName: '${item.companyName} · ${item.category}',
              unit: item.category,
              barcode: '',
              cost: item.amount,
              unitPrice: item.amount,
              quantity: item.quantity,
              lineSubtotal: item.amount * item.quantity,
              discount: 0,
              lineTotal: item.amount * item.quantity,
              isElectronicBalance: true,
              electronicBalanceAccountId: item.accountId,
              electronicBalanceCategory: item.category,
            ),
          ),
        ],
        productProvider: context.read<ProductProvider>(),
        electronicBalanceProvider: context
            .read<ElectronicBalanceProvider>(),
      );
      final discountAmount = _discountAmount
          .clamp(0, _subtotal)
          .toDouble();
      final cardFeeAmount = _cardFeeAmount;
      final total = _total;
      final finalItems = updated.items
          .map((item) {
            final lineSubtotal = item.lineSubtotal;
            final lineDiscount = _subtotal <= 0
                ? 0.0
                : discountAmount * lineSubtotal / _subtotal;
            return SaleItemRecord(
              productId: item.productId,
              productName: item.productName,
              unit: item.unit,
              brand: item.brand,
              barcode: item.barcode,
              cost: item.cost,
              unitPrice: item.unitPrice,
              quantity: item.quantity,
              lineSubtotal: lineSubtotal,
              discount: lineDiscount,
              lineTotal: lineSubtotal - lineDiscount,
              imageData: item.imageData,
              isElectronicBalance: item.isElectronicBalance,
              electronicBalanceAccountId:
                  item.electronicBalanceAccountId,
              electronicBalanceCategory: item.electronicBalanceCategory,
            );
          })
          .toList(growable: false);
      updated.clientId = clientId;
      updated.clientName = _selectedDebtor ?? 'Consumidor final';
      updated.paymentMethod = _paymentMethodLabel(
        _selectedPaymentMethod,
      );
      updated.items = finalItems;
      updated.subtotal = _subtotal;
      updated.discountAmount = discountAmount;
      updated.discountPercent = _subtotal <= 0
          ? 0
          : discountAmount / _subtotal * 100;
      updated.cardFeeAmount = cardFeeAmount;
      updated.total = total;
      updated.received = effectiveReceived;
      updated.change = _selectedPaymentMethod == AppPaymentMethods.cash
          ? _change
          : 0;
      context.read<DebtProvider>().syncInitialPayment(
        saleId: updated.id,
        clientId: clientId ?? editing.clientId ?? '',
        clientName: updated.clientName,
        amount: updated.paymentMethod == AppStrings.creditPayment
            ? effectiveReceived
            : 0,
      );
      _clearCart();
      setState(() {
        _editingSale = null;
        _selectedPaymentMethod = AppPaymentMethods.cash;
      });
      AppAlert.show(
        context,
        'La venta #${updated.ticketNumber} fue actualizada correctamente.',
        title: 'Venta actualizada',
        type: AppAlertType.success,
      );
    } catch (error) {
      AppAlert.show(
        context,
        error is StateError
            ? error.message
            : 'No se pudo actualizar la venta.',
        title: 'Error al actualizar',
        type: AppAlertType.error,
      );
    }
  }

  Future<void> _openElectronicBalanceSelector() async {
    await showDialog<void>(
      context: context,
      builder: (_) => ElectronicBalanceSaleDialog(
        initialSelection: _electronicBalanceSelection,
        onSelectionChanged: (selection) {
          if (!mounted) return;
          setState(() => _electronicBalanceSelection = selection);
        },
      ),
    );
  }

  Future<void> _openElectronicBalanceManagement() async {
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) => const ElectronicBalanceManagementDialog(),
    );
  }

  Future<void> _createSale() async {
    if (_cartQuantities.isEmpty &&
        _electronicBalanceSelection.isEmpty) {
      AppAlert.show(
        context,
        'Agrega al menos un producto o una recarga antes de crear la venta.',
        title: 'No se puede crear la venta',
        type: AppAlertType.warning,
      );
      return;
    }
    if (_discountAmount < 0 || _discountAmount > _subtotal) {
      AppAlert.show(
        context,
        'El descuento no puede ser negativo ni superar el subtotal.',
        title: 'Descuento inválido',
        type: AppAlertType.warning,
      );
      return;
    }
    if (_selectedPaymentMethod == AppPaymentMethods.credit &&
        (_selectedDebtor == null || _selectedDebtor!.trim().isEmpty)) {
      AppAlert.show(
        context,
        'Selecciona un cliente para registrar una venta a crédito.',
        title: 'Cliente requerido',
        type: AppAlertType.warning,
      );
      return;
    }
    final catalog = context.read<CatalogProvider>();
    String? clientId;
    if (_selectedDebtor != null)
      for (final client in catalog.clients) {
        if (client.name == _selectedDebtor) {
          clientId = client.id;
          break;
        }
      }
    final electronicSales = _electronicBalanceSelection
        .map(
          (item) => ElectronicBalanceCartSale(
            accountId: item.accountId,
            companyName: item.companyName,
            category: item.category,
            amount: item.amount,
            quantity: item.quantity,
          ),
        )
        .toList();
    final received =
        double.tryParse(
          _cashReceivedController.text.replaceAll(',', '.'),
        ) ??
        0;
    final initialCreditPayment =
        _selectedPaymentMethod == AppPaymentMethods.credit
        ? received.clamp(0, _total).toDouble()
        : 0.0;
    SaleRecord sale;
    try {
      sale = context.read<SalesProvider>().createSale(
        cartQuantities: Map<String, int>.from(_cartQuantities),
        productProvider: context.read<ProductProvider>(),
        paymentMethodLabel: _paymentMethodLabel(_selectedPaymentMethod),
        clientId: clientId,
        clientName: _selectedDebtor ?? 'Consumidor final',
        subtotal: _subtotal,
        discountPercent: _discountPercent,
        discountAmount: _discountAmount,
        cardFeeAmount: _cardFeeAmount,
        total: _total,
        received: _selectedPaymentMethod == AppPaymentMethods.cash
            ? received
            : initialCreditPayment,
        change: _selectedPaymentMethod == AppPaymentMethods.cash
            ? _change
            : 0,
        electronicSales: electronicSales,
        electronicBalanceProvider: context
            .read<ElectronicBalanceProvider>(),
      );
      if (_selectedPaymentMethod == AppPaymentMethods.credit &&
          initialCreditPayment > 0) {
        final saved = context.read<DebtProvider>().recordPayment(
          clientId: clientId!,
          clientName: _selectedDebtor!,
          amount: initialCreditPayment,
        );
        if (!saved) {
          context.read<SalesProvider>().deleteSale(
            saleId: sale.id,
            productProvider: context.read<ProductProvider>(),
            electronicBalanceProvider: context
                .read<ElectronicBalanceProvider>(),
          );
          throw StateError(
            'No se pudo registrar el abono inicial de la venta.',
          );
        }
      }
    } catch (error) {
      AppAlert.show(
        context,
        error is StateError
            ? error.message
            : 'No se pudo registrar la venta.',
        title: 'Error al crear la venta',
        type: AppAlertType.error,
      );
      return;
    }
    _clearCart();
    setState(() => _selectedPaymentMethod = AppPaymentMethods.cash);
    if (!mounted) return;
    await SaleSuccessDialog.show(
      context,
      sale: sale,
      onPrint: () => _printSale(sale),
    );
  }

  Future<bool> _printSale(SaleRecord sale) async {
    final printerProvider = context.read<PrinterProvider>();
    final printed = await printerProvider.printSaleTicket(sale);
    if (!mounted) return printed;
    AppAlert.show(
      context,
      printed
          ? 'El ticket fue enviado a la impresora.'
          : (printerProvider.errorMessage ??
                'No se pudo imprimir el ticket.'),
      title: printed ? 'Impresión completada' : 'No se pudo imprimir',
      type: printed ? AppAlertType.success : AppAlertType.warning,
    );
    return printed;
  }

  void _onNavigationChanged(int index) =>
      setState(() => _selectedNavIndex = index);
  void _onTagChanged(int index) =>
      setState(() => _selectedTagIndex = index);
  void _onFilterChanged(String? filter) =>
      setState(() => _selectedFilter = filter);
  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().productMaps;
    return Scaffold(
      backgroundColor: AppColors.inputBackground,
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: _handleBarcodeKey,
          child: Row(
            children: [
              SidebarDrawer(
                isExpanded: _isSidebarExpanded,
                selectedIndex: _selectedNavIndex,
                onToggleExpand: () => setState(
                  () => _isSidebarExpanded = !_isSidebarExpanded,
                ),
                onItemSelected: _onNavigationChanged,
              ),
              Expanded(child: _buildMainContent(products)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(List<Map<String, dynamic>> products) {
    if (_selectedNavIndex == AppNavigation.inventory)
      return const InventoryLayout();
    if (_selectedNavIndex == AppNavigation.electronicBalance)
      return const SalesLayout();
    if (_selectedNavIndex == AppNavigation.purchases)
      return const PurchasesLayout();
    if (_selectedNavIndex == AppNavigation.providers)
      return const ProvidersLayout();
    if (_selectedNavIndex == AppNavigation.debts)
      return const DebtsLayout();
    if (_selectedNavIndex == AppNavigation.settings)
      return const PrinterSettingsLayout();
    if (_selectedNavIndex != AppNavigation.home)
      return const _EmptySectionPanel();
    final salesCatalog = _salesCatalog;
    final combinedCart = _combinedCartQuantities;
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: CentralProductGrid(
              products: products,
              cartQuantities: combinedCart,
              tags: _tags,
              selectedTagIndex: _selectedTagIndex,
              onTagSelected: _onTagChanged,
              selectedFilter: _selectedFilter,
              onFilterChanged: _onFilterChanged,
              onAddToCart: _addToCart,
              onRemoveFromCart: _removeFromCart,
              onElectronicBalanceTap: _openElectronicBalanceSelector,
              onElectronicBalanceManage:
                  _openElectronicBalanceManagement,
              electronicBalanceSelection: _electronicBalanceSelection,
              onSearchChanged: (value) =>
                  setState(() => _searchQuery = value),
              searchQuery: _searchQuery,
            ),
          ),
          const SizedBox(width: AppDimensions.productGridSpacing),
          Expanded(
            flex: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SalesSummaryWithKeypad(
                  cartQuantities: combinedCart,
                  products: salesCatalog,
                  selectedPaymentMethod: _selectedPaymentMethod,
                  onPaymentMethodChanged: (method) =>
                      setState(() => _selectedPaymentMethod = method),
                  selectedDebtor: _selectedDebtor,
                  debtorsList: _debtors,
                  onDebtorChanged: (debtor) =>
                      setState(() => _selectedDebtor = debtor),
                  discountAmountController: _discountAmountController,
                  discountPercentController: _discountPercentController,
                  cashReceivedController: _cashReceivedController,
                  onDiscountAmountChanged: _onDiscountAmountChanged,
                  onDiscountPercentChanged: _onDiscountPercentChanged,
                  onCashReceivedChanged: (_) => setState(() {}),
                  subtotal: _subtotal,
                  cardFeeAmount: _cardFeeAmount,
                  total: _total,
                  change: _change,
                  onAddToCart: _addToCart,
                  onDecrementQuantity: _decrementQuantity,
                  onQuantityChanged: _setCartQuantity,
                  onRemoveFromCart: _removeFromCart,
                  onClearCart: _clearCart,
                  onCreateSale: _editingSale == null
                      ? _createSale
                      : _updateSale,
                  isEditing: _editingSale != null,
                  ticketNumber:
                      _editingSale?.ticketNumber ??
                      context
                          .watch<SalesProvider>()
                          .nextTicketNumberPreview,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionPanel extends StatelessWidget {
  const _EmptySectionPanel();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _ProductNotFoundAlert extends StatelessWidget {
  const _ProductNotFoundAlert();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: AppColors.warningOrange,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: const Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: Colors.white,
          size: 22,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Producto no encontrado',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
