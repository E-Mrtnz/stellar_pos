import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/presentation/Inventory/widgets/create_client_dialog.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/numeric_keypad.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/sales_summary_panel.dart';

class SalesSummaryWithKeypad extends StatefulWidget {
  final Map<String, int> cartQuantities;
  final List<Map<String, dynamic>> products;
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
  final double total;
  final double change;
  final ValueChanged<String> onAddToCart;
  final ValueChanged<String> onDecrementQuantity;
  final void Function(String productId, int quantity) onQuantityChanged;
  final ValueChanged<String> onRemoveFromCart;
  final VoidCallback onClearCart;
  final VoidCallback onCreateSale;
  final String ticketNumber;

  const SalesSummaryWithKeypad({
    super.key,
    required this.cartQuantities,
    required this.products,
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
    required this.total,
    required this.change,
    required this.onAddToCart,
    required this.onDecrementQuantity,
    required this.onQuantityChanged,
    required this.onRemoveFromCart,
    required this.onClearCart,
    required this.onCreateSale,
    required this.ticketNumber,
  });

  @override
  State<SalesSummaryWithKeypad> createState() => _SalesSummaryWithKeypadState();
}

class _SalesSummaryWithKeypadState extends State<SalesSummaryWithKeypad> {
  static const double _keypadGap = 8;
  static const double _screenPadding = 8;
  static const double _creditPanelHeight = 196;

  final GlobalKey _panelKey = GlobalKey();
  final Object _keypadGroup = EditableText;

  TextEditingController? _activeController;
  ValueChanged<String>? _activeOnChanged;
  OverlayEntry? _keypadOverlayEntry;
  Offset _keypadPosition = Offset.zero;

  Future<void> _createClientAndSelect() async {
    final catalog = context.read<CatalogProvider>();
    final beforeIds = catalog.clients.map((client) => client.id).toSet();

    await CreateClientDialog.show(context);
    if (!mounted) return;

    final created = catalog.clients.where((client) => !beforeIds.contains(client.id)).toList();
    if (created.isNotEmpty) {
      widget.onDebtorChanged(created.last.name);
    }
  }

  void _activate(
    TextEditingController controller,
    ValueChanged<String> onChanged,
  ) {
    if (!mounted) return;

    setState(() {
      _activeController = controller;
      _activeOnChanged = onChanged;
    });

    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateKeypadPosition();
      if (_keypadOverlayEntry == null) {
        _showKeypadOverlay();
      } else {
        _keypadOverlayEntry!.markNeedsBuild();
      }
    });
  }

  void _updateKeypadPosition() {
    final renderObject = _panelKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final screenSize = MediaQuery.sizeOf(context);
    final desiredLeft = topLeft.dx - NumericKeypad.width - _keypadGap;
    final desiredTop = topLeft.dy + size.height - NumericKeypad.height;
    final maxLeft = screenSize.width - NumericKeypad.width - _screenPadding;
    final maxTop = screenSize.height - NumericKeypad.height - _screenPadding;

    _keypadPosition = Offset(
      desiredLeft.clamp(
        _screenPadding,
        maxLeft < _screenPadding ? _screenPadding : maxLeft,
      ),
      desiredTop.clamp(
        _screenPadding,
        maxTop < _screenPadding ? _screenPadding : maxTop,
      ),
    );
  }

  void _showKeypadOverlay() {
    if (!mounted || _activeController == null || _keypadOverlayEntry != null) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    _keypadOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: _keypadPosition.dx,
        top: _keypadPosition.dy,
        width: NumericKeypad.width,
        height: NumericKeypad.height,
        child: TapRegion(
          groupId: _keypadGroup,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: NumericKeypad(
              onInput: _input,
              onBackspace: _backspace,
              onClear: _clear,
              onDecimal: _decimal,
            ),
          ),
        ),
      ),
    );
    overlay.insert(_keypadOverlayEntry!);
  }

  void _closeKeypad() {
    _keypadOverlayEntry?.remove();
    _keypadOverlayEntry = null;
    if (!mounted) return;
    setState(() {
      _activeController = null;
      _activeOnChanged = null;
    });
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  void _setText(String value) {
    final controller = _activeController;
    final onChanged = _activeOnChanged;
    if (controller == null || onChanged == null) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    onChanged(value);
  }

  void _input(String digit) {
    final controller = _activeController;
    if (controller == null) return;
    _setText('${controller.text}$digit');
  }

  void _decimal() {
    final controller = _activeController;
    if (controller == null || controller.text.contains('.')) return;
    _setText(controller.text.isEmpty ? '0.' : '${controller.text}.');
  }

  void _backspace() {
    final controller = _activeController;
    if (controller == null || controller.text.isEmpty) return;
    _setText(controller.text.substring(0, controller.text.length - 1));
  }

  void _clear() => _setText('');

  @override
  void dispose() {
    _keypadOverlayEntry?.remove();
    _keypadOverlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = widget.selectedPaymentMethod == AppPaymentMethods.credit;

    return TapRegion(
      groupId: _keypadGroup,
      onTapOutside: (_) => _closeKeypad(),
      child: KeyedSubtree(
        key: _panelKey,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SalesSummaryPanel(
              cartQuantities: widget.cartQuantities,
              products: widget.products,
              selectedPaymentMethod: widget.selectedPaymentMethod,
              onPaymentMethodChanged: (value) {
                _closeKeypad();
                widget.onPaymentMethodChanged(value);
              },
              selectedDebtor: widget.selectedDebtor,
              debtorsList: widget.debtorsList,
              onDebtorChanged: widget.onDebtorChanged,
              discountAmountController: widget.discountAmountController,
              discountPercentController: widget.discountPercentController,
              cashReceivedController: widget.cashReceivedController,
              onDiscountAmountChanged: widget.onDiscountAmountChanged,
              onDiscountPercentChanged: widget.onDiscountPercentChanged,
              onCashReceivedChanged: widget.onCashReceivedChanged,
              onPaymentInputFocused: (controller) {
                if (controller == widget.discountPercentController) {
                  _activate(controller, widget.onDiscountPercentChanged);
                } else if (controller == widget.discountAmountController) {
                  _activate(controller, widget.onDiscountAmountChanged);
                } else if (controller == widget.cashReceivedController) {
                  _activate(controller, widget.onCashReceivedChanged);
                }
              },
              subtotal: widget.subtotal,
              cardFeeAmount: widget.cardFeeAmount,
              total: widget.total,
              change: widget.change,
              onAddToCart: widget.onAddToCart,
              onDecrementQuantity: widget.onDecrementQuantity,
              onQuantityChanged: widget.onQuantityChanged,
              onRemoveFromCart: widget.onRemoveFromCart,
              onClearCart: widget.onClearCart,
              ticketNumber: widget.ticketNumber,
            ),
            if (isCredit)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _creditPanelHeight,
                child: _CreditPaymentPanel(
                  clientName: widget.selectedDebtor,
                  clients: widget.debtorsList,
                  total: widget.total,
                  controller: widget.cashReceivedController,
                  onClientChanged: widget.onDebtorChanged,
                  onCreateClient: _createClientAndSelect,
                  onFocusAmount: () => _activate(
                    widget.cashReceivedController,
                    widget.onCashReceivedChanged,
                  ),
                  onAmountChanged: widget.onCashReceivedChanged,
                  onCreateSale: widget.onCreateSale,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreditPaymentPanel extends StatelessWidget {
  static const String _createClientValue = '__create_client__';

  final String? clientName;
  final List<String> clients;
  final double total;
  final TextEditingController controller;
  final ValueChanged<String?> onClientChanged;
  final VoidCallback onCreateClient;
  final VoidCallback onFocusAmount;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onCreateSale;

  const _CreditPaymentPanel({
    required this.clientName,
    required this.clients,
    required this.total,
    required this.controller,
    required this.onClientChanged,
    required this.onCreateClient,
    required this.onFocusAmount,
    required this.onAmountChanged,
    required this.onCreateSale,
  });

  double get _received => double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
  double get _applied => _received.clamp(0, total).toDouble();
  double get _change => (_received - total).clamp(0, double.infinity).toDouble();

  @override
  Widget build(BuildContext context) {
    final selectedValue = clientName != null && clients.contains(clientName) ? clientName : null;

    return Material(
      color: AppColors.cardBackground,
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Detalles de pago · Fiado', style: AppTextStyles.sectionTitle),
                ),
                Text(
                  'Total \$${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedValue,
                        hint: const Text('Seleccionar cliente', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        icon: const Icon(Icons.keyboard_arrow_down, size: 17),
                        items: [
                          ...clients.map(
                            (client) => DropdownMenuItem<String>(
                              value: client,
                              child: Text(client, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                          const DropdownMenuItem<String>(
                            value: _createClientValue,
                            child: Row(
                              children: [
                                Icon(Icons.person_add_alt_1_outlined, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('Crear cliente', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == _createClientValue) {
                            onCreateClient();
                          } else {
                            onClientChanged(value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 82,
                  height: 34,
                  child: TextField(
                    controller: controller,
                    readOnly: true,
                    onTap: onFocusAmount,
                    onChanged: onAmountChanged,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      hintText: '0.00',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                      filled: true,
                      fillColor: AppColors.inputBackground,
                      labelText: 'Abonado',
                      labelStyle: const TextStyle(fontSize: 9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Deuda después del abono: \$${(total - _applied).clamp(0, double.infinity).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                  ),
                ),
                if (_change > 0.005)
                  Text(
                    'Cambio: \$${_change.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.warningOrange),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: ElevatedButton.icon(
                onPressed: clientName == null || clientName!.trim().isEmpty ? null : onCreateSale,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Crear venta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  disabledForegroundColor: AppColors.textMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
