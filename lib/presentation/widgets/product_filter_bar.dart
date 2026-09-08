import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';

class ProductFilterBar extends StatelessWidget {
  final List<String> tags;
  final String? selectedFilter;
  final ValueChanged<String?> onFilterChanged;
  final int selectedTagIndex;
  final ValueChanged<int> onTagSelected;
  const ProductFilterBar({super.key, required this.tags, required this.selectedFilter, required this.onFilterChanged, required this.selectedTagIndex, required this.onTagSelected});

  static const _filterOptions = <_FilterOption>[
    _FilterOption(id: 'all', label: 'Todos'),
    _FilterOption(id: 'missing_cost', label: 'Sin precio de compra'),
    _FilterOption(id: 'missing_barcode', label: 'Sin código de barras'),
    _FilterOption(id: 'missing_tag', label: 'Sin categoría'),
    _FilterOption(id: 'missing_department', label: 'Sin distribuidora'),
  ];

  @override
  Widget build(BuildContext context) {
    final brands = context.watch<CatalogProvider>().brands;
    return SizedBox(height: 38, child: Row(children: [
      _buildFilterDropdown(),
      const SizedBox(width: 10),
      _buildBrandDropdown(brands),
      const SizedBox(width: 10),
      Expanded(child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: tags.length + 1, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (context, index) {
        if (index == 0) return _buildTagChip(label: 'Todos', isSelected: selectedTagIndex == 0, onSelected: () => onTagSelected(0));
        final tagIndex = index - 1;
        return _buildTagChip(label: tags[tagIndex], isSelected: selectedTagIndex == tagIndex + 1, onSelected: () => onTagSelected(tagIndex + 1));
      })),
    ]));
  }

  Widget _buildFilterDropdown() => Container(width: 210, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: DropdownButtonHideUnderline(child: DropdownButton<String?>(value: _statusValue(), hint: const Text('Filtrar por...', overflow: TextOverflow.ellipsis), isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary), style: const TextStyle(fontSize: 12, color: AppColors.textPrimary), dropdownColor: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), items: [const DropdownMenuItem<String?>(value: null, child: Text('Sin filtro', overflow: TextOverflow.ellipsis)), ..._filterOptions.map((option) => DropdownMenuItem<String?>(value: option.id, child: Text(option.label, overflow: TextOverflow.ellipsis)))], onChanged: onFilterChanged)));

  String? _statusValue() => selectedFilter != null && selectedFilter!.startsWith('brand:') ? null : selectedFilter;

  Widget _buildBrandDropdown(List<String> brands) {
    final selectedBrand = selectedFilter != null && selectedFilter!.startsWith('brand:') ? selectedFilter!.substring(6) : null;
    return Container(width: 180, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: DropdownButtonHideUnderline(child: DropdownButton<String?>(value: selectedBrand, hint: const Text('Marca', overflow: TextOverflow.ellipsis), isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary), style: const TextStyle(fontSize: 12, color: AppColors.textPrimary), dropdownColor: AppColors.cardBackground, items: [const DropdownMenuItem<String?>(value: null, child: Text('Todas las marcas')), ...brands.map((brand) => DropdownMenuItem<String?>(value: brand, child: Text(brand, overflow: TextOverflow.ellipsis)))], onChanged: (value) => onFilterChanged(value == null ? null : 'brand:$value'))));
  }

  Widget _buildTagChip({required String label, required bool isSelected, required VoidCallback onSelected}) => ChoiceChip(label: Text(label, style: AppTextStyles.chipText.copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? Colors.white : AppColors.textDarkSecondary)), selected: isSelected, selectedColor: AppColors.primary, backgroundColor: AppColors.cardBackground, side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), showCheckmark: false, onSelected: (_) => onSelected());
}

class _FilterOption { final String id; final String label; const _FilterOption({required this.id, required this.label}); }
