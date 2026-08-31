import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';

class CatalogManagementDialog extends StatefulWidget {
  final bool isDepartment;

  const CatalogManagementDialog({
    super.key,
    required this.isDepartment,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isDepartment,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: CatalogManagementDialog(isDepartment: isDepartment),
      ),
    );
  }

  @override
  State<CatalogManagementDialog> createState() =>
      _CatalogManagementDialogState();
}

class _CatalogManagementDialogState
    extends State<CatalogManagementDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();

    if (value.isEmpty) {
      return;
    }

    final catalog = context.read<CatalogProvider>();

    if (widget.isDepartment) {
      catalog.addDepartment(value);
    } else {
      catalog.addTag(value);
    }

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();

    final values = widget.isDepartment
        ? catalog.departments
        : catalog.tags;

    final title = widget.isDepartment ? 'Departamentos' : 'Etiquetas';

    final hint = widget.isDepartment
        ? 'Nombre del departamento'
        : 'Nombre de la etiqueta';

    return Container(
      width: 420,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.sectionTitle.copyWith(
                    fontSize: 17,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(
                  Icons.close,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    hintText: hint,
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.border,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                onPressed: _save,
                tooltip: 'Agregar',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (values.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Todavía no hay elementos creados.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: values.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final value = values[index];

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      widget.isDepartment
                          ? Icons.business_outlined
                          : Icons.label_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    title: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 19,
                        color: AppColors.dangerRed,
                      ),
                      onPressed: () {
                        if (widget.isDepartment) {
                          catalog.removeDepartment(value);
                        } else {
                          catalog.removeTag(value);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
