import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

class ProductSearchBar extends StatefulWidget {
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
  State<ProductSearchBar> createState() => _ProductSearchBarState();
}

class _ProductSearchBarState extends State<ProductSearchBar> {
  late final TextEditingController _internalController;
  TextEditingController get _controller => widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant ProductSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      _controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _internalController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearSearch() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: _controller,
      hintText: widget.hintText,
      onChanged: widget.onChanged,
      leading: const Icon(
        Icons.search,
        color: AppColors.textSecondary,
      ),
      trailing: [
        if (_controller.text.isNotEmpty)
          IconButton(
            tooltip: 'Limpiar búsqueda',
            onPressed: _clearSearch,
            icon: const Icon(Icons.close),
            color: AppColors.textSecondary,
          ),
      ],
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
