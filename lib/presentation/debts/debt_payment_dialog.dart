import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/presentation/dashboard/widgets/numeric_keypad.dart';

class DebtPaymentDialog extends StatefulWidget {
  final String clientName;
  final double debt;
  final double? initialAmount;
  final bool editing;

  const DebtPaymentDialog({
    required this.clientName,
    required this.debt,
    this.initialAmount,
    this.editing = false,
  });

  static Future<double?> show(
    BuildContext context, {
    required String clientName,
    required double debt,
    double? initialAmount,
    bool editing = false,
  }) =>
      showDialog<double>(
        context: context,
        builder: (_) => DebtPaymentDialog(
          clientName: clientName,
          debt: debt,
          initialAmount: initialAmount,
          editing: editing,
        ),
      );

  @override
  State<DebtPaymentDialog> createState() => _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends State<DebtPaymentDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  double get _enteredAmount =>
      double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;

  double get _change =>
      (_enteredAmount - widget.debt).clamp(0, double.infinity).toDouble();

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _controller.text = widget.initialAmount!.toStringAsFixed(2);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _input(String value) {
    _controller.text += value;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() {});
  }

  void _backspace() {
    if (_controller.text.isEmpty) return;
    _controller.text = _controller.text.substring(
      0,
      _controller.text.length - 1,
    );
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    setState(() {});
  }

  void _decimal() {
    if (!_controller.text.contains('.')) _input('.');
  }

  void _save() {
    final amount = double.tryParse(_controller.text);
    if (amount == null || amount <= 0) return;
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    final hasChange = _enteredAmount > widget.debt + 0.005;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
      ),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            widget.editing ? 'Editar abono' : 'Registrar abono',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withAlpha(12),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: AppColors.successGreen.withAlpha(35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 15,
                            color: AppColors.successGreen,
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'Deuda restante',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '\u0024' + widget.debt.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'),
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: widget.editing ? 'Monto del abono' : 'Monto recibido',
                        hintText: '0.00',
                        prefixText: '\$ ',
                        prefixStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 140),
                      child: hasChange
                          ? Container(
                              key: const ValueKey('change'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warningOrange.withAlpha(12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.warningOrange.withAlpha(40),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.currency_exchange_rounded,
                                    size: 15,
                                    color: AppColors.warningOrange,
                                  ),
                                  const SizedBox(width: 7),
                                  const Expanded(
                                    child: Text(
                                      'Cambio a entregar',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '\u0024' + _change.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.warningOrange,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(
                              key: ValueKey('no-change'),
                              height: 1,
                            ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(
                                  color: AppColors.border,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'Cancelar',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: FilledButton.icon(
                              onPressed: _save,
                              icon: const Icon(
                                Icons.check_rounded,
                                size: 15,
                              ),
                              label: const Text(
                                'Registrar',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: NumericKeypad.width,
              height: NumericKeypad.height,
              child: NumericKeypad(
                onInput: _input,
                onBackspace: _backspace,
                onClear: _clear,
                onDecimal: _decimal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
