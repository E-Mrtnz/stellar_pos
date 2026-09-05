import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
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
  final int ticketNumber;

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
    required this.ticketNumber,
  });

  @override
  State<SalesSummaryWithKeypad> createState() => _SalesSummaryWithKeypadState();
}

class _SalesSummaryWithKeypadState extends State<SalesSummaryWithKeypad> {
  TextEditingController? _activeController;
  ValueChanged<String>? _activeOnChanged;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChanged);
    super.dispose();
  }

  void _handleFocusChanged() {
    final node = FocusManager.instance.primaryFocus;
    final context = node?.context;
    if (context == null) return;
    final editable = context.findAncestorWidgetOfExactType<EditableText>();
    final controller = editable?.controller;
    if (controller == widget.discountPercentController) {
      _activate(controller!, widget.onDiscountPercentChanged);
    } else if (controller == widget.discountAmountController) {
      _activate(controller!, widget.onDiscountAmountChanged);
    } else if (controller == widget.cashReceivedController) {
      _activate(controller!, widget.onCashReceivedChanged);
    }
  }

  void _activate(TextEditingController controller, ValueChanged<String> onChanged) {
    if (_activeController != controller) {
      setState(() {
        _activeController = controller;
        _activeOnChanged = onChanged;
      });
    }
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  void _closeKeypad() {
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
    if (controller != null) _setText('${controller.text}$digit');
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
  Widget build(BuildContext context) {
    return Stack(
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
          subtotal: widget.subtotal,
          cardFeeAmount: widget.cardFeeAmount,
          total: widget.total,
          change: widget.change,
          onAddToCart: widget.onAddToCart,
          onDecrementQuantity: widget.onDecrementQuantity,
          onQuantityChanged: widget.onQuantityChanged,
          onRemoveFromCart: widget.onRemoveFromCart,
          onClearCart: widget.onClearCart,
        ),
        Positioned(
          left: 92,
          top: 38,
          child: IgnorePointer(
            child: Container(
              width: 64,
              height: 20,
              color: AppColors.cardBackground,
              alignment: Alignment.centerLeft,
              child: Text('#${widget.ticketNumber}', style: AppTextStyles.ticketValue),
            ),
          ),
        ),
        if (_activeController != null)
          Positioned(
            left: -172,
            bottom: 10,
            child: NumericKeypad(
              onInput: _input,
              onBackspace: _backspace,
              onClear: _clear,
              onDecimal: _decimal,
            ),
          ),
      ],
    );
  }
}
