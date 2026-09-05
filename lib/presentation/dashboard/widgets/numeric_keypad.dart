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
    const keys = ['1','2','3','4','5','6','7','8','9'];
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 164,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 14, offset: Offset(0, 5))],
        ),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
          childAspectRatio: 1,
          children: [
            ...keys.map((key) => _Key(label: key, onTap: () => onInput(key))),
            _Key(icon: Icons.backspace_outlined, emphasized: true, onTap: onBackspace, onLongPress: onClear),
            _Key(label: '0', onTap: () => onInput('0')),
            _Key(label: '.', emphasized: true, onTap: onDecimal),
          ],
        ),
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

  const _Key({this.label, this.icon, required this.onTap, this.onLongPress, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? AppColors.warningOrange.withAlpha(18) : AppColors.inputBackground,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(9),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 18, color: emphasized ? AppColors.warningOrange : AppColors.textPrimary)
              : Text(label!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: emphasized ? AppColors.warningOrange : AppColors.textPrimary)),
        ),
      ),
    );
  }
}
