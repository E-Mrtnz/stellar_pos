import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

class ProductSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const ProductSearchBar({
    super.key,
    this.hintText = AppStrings.searchPlaceholder,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: controller,
      hintText: hintText,
      onChanged: onChanged,
      leading: const Icon(
        Icons.search,
        color: AppColors.textSecondary,
      ),
      constraints: const BoxConstraints(
        minHeight: 48,
      ),
      backgroundColor: const WidgetStatePropertyAll(AppColors.cardBackground),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      side: const WidgetStatePropertyAll(
        BorderSide(color: AppColors.border),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppDimensions.searchFieldRadius),
          ),
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      hintStyle: const WidgetStatePropertyAll(AppTextStyles.searchHint),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
