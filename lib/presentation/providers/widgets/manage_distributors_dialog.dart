import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';
import 'package:stellar_pos/presentation/widgets/app_confirm_dialog.dart';

class ManageDistributorsDialog extends StatefulWidget {
  const ManageDistributorsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.overlayBackground,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ManageDistributorsDialog(),
      ),
    );
  }

  @override
  State<ManageDistributorsDialog> createState() =>
      _ManageDistributorsDialogState();
}

class _ManageDistributorsDialogState extends State<ManageDistributorsDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _editingName;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;

    final providers = context.read<ProvidersProvider>();
    final catalog = context.read<CatalogProvider>();
    final isEditing = _editingName != null;

    if (isEditing) {
      final confirmed = await AppConfirmDialog.update(
        context,
        itemName: 'esta distribuidora',
      );
      if (!confirmed || !mounted) return;
    }

    final success = isEditing
        ? providers.updateDistributor(_editingName!, value)
        : providers.addDistributor(value);

    if (!success) {
      AppAlert.show(
        context,
        'Ya existe una distribuidora con ese nombre.',
        title: 'No se pudo guardar',
        type: AppAlertType.warning,
      );
      return;
    }

    if (!isEditing) {
      catalog.addDistributor(value);
    } else {
      catalog.removeDistributor(_editingName!);
      catalog.addDistributor(value);
    }

    AppAlert.show(
      context,
      isEditing
          ? 'La distribuidora se actualizó correctamente.'
          : 'La distribuidora se creó correctamente.',
      title: isEditing ? 'Distribuidora actualizada' : 'Distribuidora creada',
      type: AppAlertType.success,
    );

    _controller.clear();
    setState(() => _editingName = null);
  }

  void _startEdit(String name) {
    setState(() {
      _editingName = name;
      _controller.text = name;
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

  Future<void> _delete(String name) async {
    final confirmed = await AppConfirmDialog.delete(
      context,
      itemName: 'esta distribuidora',
    );
    if (!confirmed || !mounted) return;

    final success = context.read<ProvidersProvider>().removeDistributor(name);
    if (!success) {
      AppAlert.show(
        context,
        'No puedes eliminar esta distribuidora porque tiene rutas asignadas.',
        title: 'No se puede eliminar',
        type: AppAlertType.warning,
      );
      return;
    }

    context.read<CatalogProvider>().removeDistributor(name);

    if (_editingName?.toLowerCase() == name.toLowerCase()) {
      _cancelEdit();
    }

    AppAlert.show(
      context,
      'La distribuidora se eliminó correctamente.',
      title: 'Distribuidora eliminada',
      type: AppAlertType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final distributors = context.watch<ProvidersProvider>().distributors;
    final editing = _editingName != null;

    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Distribuidoras',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
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
                      isDense: true,
                      hintText: 'Nombre de la distribuidora',
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
                  tooltip: editing
                      ? 'Guardar cambios'
                      : 'Agregar distribuidora',
                  onPressed: _save,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(editing ? Icons.check : Icons.add),
                ),
                if (editing)
                  IconButton(
                    tooltip: 'Cancelar edición',
                    onPressed: _cancelEdit,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (distributors.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Todavía no hay distribuidoras creadas.',
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
                  itemCount: distributors.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final name = distributors[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.business_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      title: Text(
                        name,
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
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                            ),
                            color: AppColors.primary,
                            onPressed: () => _startEdit(name),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 19,
                              color: AppColors.dangerRed,
                            ),
                            onPressed: () => _delete(name),
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
