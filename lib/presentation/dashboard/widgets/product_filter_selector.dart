import 'package:flutter/material.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';

enum ProductFilterType {
  all,
  missingCost,
  missingBarcode,
  missingTag,
  missingDepartment,
  tag,
  department,
}

class ProductFilterOption {
  final String id;
  final String label;
  final ProductFilterType type;

  const ProductFilterOption({
    required this.id,
    required this.label,
    required this.type,
  });
}

class ProductFilterSelector extends StatelessWidget {
  final List<String> tags;
  final List<String> departments;
  final String selectedId;
  final ValueChanged<String> onChanged;

  const ProductFilterSelector({
    super.key,
    required this.tags,
    required this.departments,
    required this.selectedId,
    required this.onChanged,
  });

  List<ProductFilterOption> get _options {
    final options = <ProductFilterOption>[
      const ProductFilterOption(
        id: 'all',
        label: 'Todos',
        type: ProductFilterType.all,
      ),
      const ProductFilterOption(
        id: 'missing_cost',
        label: 'Sin precio de compra',
        type: ProductFilterType.missingCost,
      ),
      const ProductFilterOption(
        id: 'missing_barcode',
        label: 'Sin código de barras',
        type: ProductFilterType.missingBarcode,
      ),
      const ProductFilterOption(
        id: 'missing_tag',
        label: 'Sin etiqueta',
        type: ProductFilterType.missingTag,
      ),
      const ProductFilterOption(
        id: 'missing_department',
        label: 'Sin departamento',
        type: ProductFilterType.missingDepartment,
      ),
    ];

    for (final tag in tags) {
      options.add(
        ProductFilterOption(
          id: 'tag:$tag',
          label: 'Etiqueta: $tag',
          type: ProductFilterType.tag,
        ),
      );
    }

    for (final department in departments) {
      options.add(
        ProductFilterOption(
          id: 'department:$department',
          label: 'Departamento: $department',
          type: ProductFilterType.department,
        ),
      );
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;

    final selectedExists = options.any(
      (option) => option.id == selectedId,
    );

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedExists ? selectedId : 'all',
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
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option.id,
              child: Text(
                option.label,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}
