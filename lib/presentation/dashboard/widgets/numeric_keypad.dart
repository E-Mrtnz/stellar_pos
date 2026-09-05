import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

class NumericKeypad extends StatelessWidget {
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
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];

    return SizedBox(
      width: 164,
      height: 214,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 164,
          height: 214,
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
              _buildRow([
                _Key(label: keys[0], onTap: () => onInput(keys[0])),
                _Key(label: keys[1], onTap: () => onInput(keys[1])),
                _Key(label: keys[2], onTap: () => onInput(keys[2])),
              ]),
              const SizedBox(height: 7),
              _buildRow([
                _Key(label: keys[3], onTap: () => onInput(keys[3])),
                _Key(label: keys[4], onTap: () => onInput(keys[4])),
                _Key(label: keys[5], onTap: () => onInput(keys[5])),
              ]),
              const SizedBox(height: 7),
              _buildRow([
                _Key(label: keys[6], onTap: () => onInput(keys[6])),
                _Key(label: keys[7], onTap: () => onInput(keys[7])),
                _Key(label: keys[8], onTap: () => onInput(keys[8])),
              ]),
              const SizedBox(height: 7),
              _buildRow([
                _Key(
                  icon: Icons.backspace_outlined,
                  emphasized: true,
                  onTap: onBackspace,
                  onLongPress: onClear,
                ),
                _Key(label: '0', onTap: () => onInput('0')),
                _Key(label: '.', emphasized: true, onTap: onDecimal),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<Widget> children) {
    return SizedBox(
      height: 43,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i != children.length - 1) const SizedBox(width: 7),
          ],
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
