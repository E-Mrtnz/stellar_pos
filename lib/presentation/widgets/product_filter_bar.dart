import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

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

  static const List<_FilterOption> _filterOptions = [
    _FilterOption(
      id: 'all',
      label: 'Todos',
    ),
    _FilterOption(
      id: 'missing_cost',
      label: 'Sin precio de compra',
    ),
    _FilterOption(
      id: 'missing_barcode',
      label: 'Sin código de barras',
    ),
    _FilterOption(
      id: 'missing_tag',
      label: 'Sin etiqueta',
    ),
    _FilterOption(
      id: 'missing_department',
      label: 'Sin departamento',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          _buildFilterDropdown(),
          const SizedBox(width: 10),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tags.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildTagChip(
                    label: 'Todos',
                    isSelected: selectedTagIndex == 0,
                    onSelected: () => onTagSelected(0),
                  );
                }

                final tagIndex = index - 1;

                return _buildTagChip(
                  label: tags[tagIndex],
                  isSelected: selectedTagIndex == tagIndex + 1,
                  onSelected: () => onTagSelected(tagIndex + 1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedFilter,
          hint: const Text(
            'Filtrar por...',
            overflow: TextOverflow.ellipsis,
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
          ),
          dropdownColor: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Sin filtro',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ..._filterOptions.map((option) {
              return DropdownMenuItem<String?>(
                value: option.id,
                child: Text(
                  option.label,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: onFilterChanged,
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
          color: isSelected ? Colors.white : AppColors.textDarkSecondary,
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
