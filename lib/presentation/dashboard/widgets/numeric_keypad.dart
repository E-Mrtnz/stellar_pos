import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

/// Compact numeric keypad used by the payment inputs.
///
/// The widget deliberately has a fixed visual size. Positioning is handled by
/// the parent overlay, so this widget never participates in the dashboard's
/// responsive layout constraints.
class NumericKeypad extends StatelessWidget {
  static const double width = 164;
  static const double height = 214;

  final ValueChanged<String> onInput;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onDecimal;

  const NumericKeypad({
    super.key,
    required this.onInput,
    required this.onBackspace,
    required this.onClear,
    required this.onDecimal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              _row(const ['1', '2', '3']),
              const SizedBox(height: 7),
              _row(const ['4', '5', '6']),
              const SizedBox(height: 7),
              _row(const ['7', '8', '9']),
              const SizedBox(height: 7),
              _lastRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(List<String> values) {
    return SizedBox(
      height: 43,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
              child: _Key(
                label: values[i],
                onTap: () => onInput(values[i]),
              ),
            ),
            if (i < values.length - 1) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  Widget _lastRow() {
    return SizedBox(
      height: 43,
      child: Row(
        children: [
          Expanded(
            child: _Key(
              icon: Icons.backspace_outlined,
              emphasized: true,
              onTap: onBackspace,
              onLongPress: onClear,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _Key(
              label: '0',
              onTap: () => onInput('0'),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _Key(
              label: '.',
              emphasized: true,
              onTap: onDecimal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool emphasized;

  const _Key({
    this.label,
    this.icon,
    required this.onTap,
    this.onLongPress,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized
          ? AppColors.warningOrange.withAlpha(18)
          : AppColors.inputBackground,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(9),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: emphasized
                      ? AppColors.warningOrange
                      : AppColors.textPrimary,
                )
              : Text(
                  label!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: emphasized
                        ? AppColors.warningOrange
                        : AppColors.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}
