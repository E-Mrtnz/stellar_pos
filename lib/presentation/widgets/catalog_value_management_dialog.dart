import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';
import 'package:stellar_pos/presentation/widgets/app_confirm_dialog.dart';

enum CatalogValueType { category, brand, distributor }

class CatalogValueManagementDialog extends StatefulWidget {
  final CatalogValueType type;

  const CatalogValueManagementDialog({super.key, required this.type});

  static Future<void> show(
    BuildContext context, {
    required CatalogValueType type,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: CatalogValueManagementDialog(type: type),
      ),
    );
  }

  @override
  State<CatalogValueManagementDialog> createState() =>
      _CatalogValueManagementDialogState();
}

class _CatalogValueManagementDialogState
    extends State<CatalogValueManagementDialog> {
  final _controller = TextEditingController();
  String? _editingName;

  bool get _editing => _editingName != null;

  String get _title {
    switch (widget.type) {
      case CatalogValueType.category:
        return 'Categorías';
      case CatalogValueType.brand:
        return 'Marcas';
      case CatalogValueType.distributor:
        return 'Distribuidoras';
    }
  }

  String get _singular {
    switch (widget.type) {
      case CatalogValueType.category:
        return 'categoría';
      case CatalogValueType.brand:
        return 'marca';
      case CatalogValueType.distributor:
        return 'distribuidora';
    }
  }

  String get _hint => 'Nombre de la $_singular';

  List<String> _values(CatalogProvider catalog) {
    switch (widget.type) {
      case CatalogValueType.category:
        return catalog.tags;
      case CatalogValueType.brand:
        return catalog.brands;
      case CatalogValueType.distributor:
        return catalog.distributors;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case CatalogValueType.category:
        return Icons.label_outline;
      case CatalogValueType.brand:
        return Icons.sell_outlined;
      case CatalogValueType.distributor:
        return Icons.business_outlined;
    }
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;

    final catalog = context.read<CatalogProvider>();
    final oldValue = _editingName;
    final isEditing = oldValue != null;

    if (isEditing) {
      final confirmed = await AppConfirmDialog.update(
        context,
        itemName: 'esta $_singular',
      );
      if (!confirmed || !mounted) return;
    }

    final success = switch (widget.type) {
      CatalogValueType.category => isEditing
          ? catalog.updateTag(oldValue!, value)
          : catalog.addTag(value),
      CatalogValueType.brand => isEditing
          ? catalog.updateBrand(oldValue!, value)
          : catalog.addBrand(value),
      CatalogValueType.distributor => isEditing
          ? catalog.updateDistributor(oldValue!, value)
          : catalog.addDistributor(value),
    };

    if (!success) {
      AppAlert.show(
        context,
        'Ya existe una $_singular con ese nombre.',
        title: 'No se pudo guardar',
        type: AppAlertType.warning,
      );
      return;
    }

    AppAlert.show(
      context,
      isEditing
          ? 'La $_singular se actualizó correctamente.'
          : 'La $_singular se creó correctamente.',
      title: isEditing
          ? '${_capitalize(_singular)} actualizada'
          : '${_capitalize(_singular)} creada',
      type: AppAlertType.success,
    );

    setState(() {
      _editingName = null;
      _controller.clear();
    });
  }

  void _startEdit(String value) {
    setState(() {
      _editingName = value;
      _controller.text = value;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingName = null;
      _controller.clear();
    });
  }

  Future<void> _delete(String value) async {
    final confirmed = await AppConfirmDialog.delete(
      context,
      itemName: 'esta $_singular',
    );
    if (!confirmed || !mounted) return;

    final catalog = context.read<CatalogProvider>();
    final success = switch (widget.type) {
      CatalogValueType.category => catalog.removeTag(value),
      CatalogValueType.brand => catalog.removeBrand(value),
      CatalogValueType.distributor => catalog.removeDistributor(value),
    };

    if (!success) return;

    if (_editingName?.toLowerCase() == value.toLowerCase()) {
      _cancelEdit();
    }

    AppAlert.show(
      context,
      'La $_singular se eliminó correctamente.',
      title: '${_capitalize(_singular)} eliminada',
      type: AppAlertType.success,
    );
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = _values(context.watch<CatalogProvider>());

    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _hint,
                      filled: true,
                      fillColor: AppColors.inputBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _editing ? 'Guardar cambios' : 'Agregar',
                  onPressed: _save,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(_editing ? Icons.check : Icons.add),
                ),
                if (_editing)
                  IconButton(
                    tooltip: 'Cancelar edición',
                    onPressed: _cancelEdit,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (values.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Todavía no hay $_singular${_singular.endsWith('a') ? 's' : 's'} creadas.',
                  style: const TextStyle(
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
                        _icon,
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: AppColors.primary,
                            onPressed: () => _startEdit(value),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 19,
                              color: AppColors.dangerRed,
                            ),
                            onPressed: () => _delete(value),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
