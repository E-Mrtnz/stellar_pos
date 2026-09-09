import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';

class ProductFilterBar extends StatelessWidget {
  final List<String> tags;
  final String? selectedFilter;
  final ValueChanged<String?> onFilterChanged;
  final int selectedTagIndex;
  final ValueChanged<int> onTagSelected;

  const ProductFilterBar({
    super.key,
    required this.tags,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.selectedTagIndex,
    required this.onTagSelected,
  });

  static const _filterOptions = <_FilterOption>[
    _FilterOption(id: 'all', label: 'Todos'),
    _FilterOption(id: 'missing_cost', label: 'Sin precio de compra'),
    _FilterOption(id: 'missing_barcode', label: 'Sin código de barras'),
    _FilterOption(id: 'missing_tag', label: 'Sin categoría'),
    _FilterOption(id: 'missing_department', label: 'Sin distribuidora'),
  ];

  static const _dropdownTextStyle = TextStyle(
    fontSize: 12,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final productProvider = context.watch<ProductProvider>();
    final providersProvider = context.watch<ProvidersProvider>();

    final catalogBrands = catalog.brands;
    final productBrands = productProvider.products
        .map((p) => p.brand.trim())
        .where((b) => b.isNotEmpty)
        .toSet();
    final brands = {...catalogBrands, ...productBrands}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final catalogDistributors = providersProvider.distributors;
    final productDistributors = productProvider.products
        .map((p) => p.department.trim())
        .where((d) => d.isNotEmpty)
        .toSet();
    final distributors = {...catalogDistributors, ...productDistributors}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length + 4,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildFilterDropdown(context);
          }
          if (index == 1) {
            return _buildBrandDropdown(context, brands);
          }
          if (index == 2) {
            return _buildDistributorDropdown(context, distributors);
          }

          final tagIndex = index - 3;
          if (tagIndex == 0) {
            return _buildTagChip(
              label: 'Todos',
              isSelected: selectedTagIndex == 0,
              onSelected: () => onTagSelected(0),
            );
          }

          final categoryIndex = tagIndex - 1;
          return _buildTagChip(
            label: tags[categoryIndex],
            isSelected: selectedTagIndex == categoryIndex + 1,
            onSelected: () => onTagSelected(categoryIndex + 1),
          );
        },
      ),
    );
  }

  double _contentWidth(BuildContext context, List<String> labels) {
    final textDirection = Directionality.of(context);
    var maxWidth = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: _dropdownTextStyle),
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      if (painter.width > maxWidth) maxWidth = painter.width;
    }
    return maxWidth + 48;
  }

  Widget _dropdownContainer({
    required double width,
    required Widget child,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _buildFilterDropdown(BuildContext context) {
    final labels = [
      'Sin filtro',
      ..._filterOptions.map((option) => option.label),
    ];
    return _dropdownContainer(
      width: _contentWidth(context, labels),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _statusValue(),
          hint: const Text('Sin filtro', overflow: TextOverflow.ellipsis),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: _dropdownTextStyle,
          dropdownColor: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin filtro', overflow: TextOverflow.ellipsis),
            ),
            ..._filterOptions.map(
              (option) => DropdownMenuItem<String?>(
                value: option.id,
                child: Text(option.label, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onFilterChanged,
        ),
      ),
    );
  }

  String? _statusValue() {
    if (selectedFilter != null &&
        (selectedFilter!.startsWith('brand:') ||
            selectedFilter!.startsWith('distributor:'))) {
      return null;
    }
    return selectedFilter;
  }

  Widget _buildBrandDropdown(BuildContext context, List<String> brands) {
    final selectedBrand = selectedFilter != null &&
            selectedFilter!.startsWith('brand:')
        ? selectedFilter!.substring(6)
        : null;
    final labels = ['Marcas', ...brands];

    return _dropdownContainer(
      width: _contentWidth(context, labels),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedBrand,
          hint: const Text('Marcas', overflow: TextOverflow.ellipsis),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: _dropdownTextStyle,
          dropdownColor: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Marcas', overflow: TextOverflow.ellipsis),
            ),
            ...brands.map(
              (brand) => DropdownMenuItem<String?>(
                value: brand,
                child: Text(brand, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) =>
              onFilterChanged(value == null ? null : 'brand:$value'),
        ),
      ),
    );
  }

  Widget _buildDistributorDropdown(
    BuildContext context,
    List<String> distributors,
  ) {
    final selectedDistributor = selectedFilter != null &&
            selectedFilter!.startsWith('distributor:')
        ? selectedFilter!.substring(11)
        : null;
    final labels = ['Distribuidoras', ...distributors];

    return _dropdownContainer(
      width: _contentWidth(context, labels),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedDistributor,
          hint: const Text(
            'Distribuidoras',
            overflow: TextOverflow.ellipsis,
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: _dropdownTextStyle,
          dropdownColor: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Distribuidoras',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...distributors.map(
              (distributor) => DropdownMenuItem<String?>(
                value: distributor,
                child: Text(
                  distributor,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (value) => onFilterChanged(
            value == null ? null : 'distributor:$value',
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: AppTextStyles.chipText.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected
              ? Colors.white
              : AppColors.textDarkSecondary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.cardBackground,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}

class _FilterOption {
  final String id;
  final String label;

  const _FilterOption({
    required this.id,
    required this.label,
  });
}
