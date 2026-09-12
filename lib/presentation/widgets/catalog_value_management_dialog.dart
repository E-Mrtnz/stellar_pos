import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/client_group_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';
import 'package:stellar_pos/presentation/widgets/app_confirm_dialog.dart';

enum CatalogValueType { category, brand, distributor, clientGroup }

class CatalogValueManagementDialog extends StatefulWidget {
  final CatalogValueType type;

  const CatalogValueManagementDialog({super.key, required this.type});

  static Future<void> show(BuildContext context, {required CatalogValueType type}) {
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
  State<CatalogValueManagementDialog> createState() => _CatalogValueManagementDialogState();
}

class _CatalogValueManagementDialogState extends State<CatalogValueManagementDialog> {
  final _controller = TextEditingController();
  String? _editingName;
  String? _editingGroupId;
  final Set<String> _selectedClientIds = <String>{};

  bool get _editing => _editingName != null;
  bool get _isClientGroup => widget.type == CatalogValueType.clientGroup;

  String get _title => switch (widget.type) {
        CatalogValueType.category => 'Categorías',
        CatalogValueType.brand => 'Marcas',
        CatalogValueType.distributor => 'Distribuidoras',
        CatalogValueType.clientGroup => 'Grupos de clientes',
      };

  String get _singular => switch (widget.type) {
        CatalogValueType.category => 'categoría',
        CatalogValueType.brand => 'marca',
        CatalogValueType.distributor => 'distribuidora',
        CatalogValueType.clientGroup => 'grupo',
      };

  List<String> _values(BuildContext context) {
    if (_isClientGroup) {
      return context.watch<ClientGroupProvider>().groups.map((group) => group.name).toList();
    }
    final catalog = context.watch<CatalogProvider>();
    return switch (widget.type) {
      CatalogValueType.category => catalog.tags,
      CatalogValueType.brand => catalog.brands,
      CatalogValueType.distributor => catalog.distributors,
      CatalogValueType.clientGroup => const [],
    };
  }

  IconData get _icon => switch (widget.type) {
        CatalogValueType.category => Icons.label_outline,
        CatalogValueType.brand => Icons.sell_outlined,
        CatalogValueType.distributor => Icons.business_outlined,
        CatalogValueType.clientGroup => Icons.groups_outlined,
      };

  bool _isDuplicate(List<String> values, String value, {String? excluding}) {
    final normalized = value.trim().toLowerCase();
    final excluded = excluding?.trim().toLowerCase();
    return values.any((item) {
      final candidate = item.trim().toLowerCase();
      return candidate == normalized && candidate != excluded;
    });
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;

    final oldValue = _editingName;
    final isEditing = oldValue != null;
    final values = _values(context);

    if (_isDuplicate(values, value, excluding: oldValue)) {
      AppAlert.show(
        context,
        'Ya existe un $_singular con ese nombre.',
        title: 'No se pudo guardar',
        type: AppAlertType.warning,
      );
      return;
    }

    if (isEditing) {
      final confirmed = await AppConfirmDialog.update(context, itemName: 'este $_singular');
      if (!confirmed || !mounted) return;
    }

    bool success;
    if (_isClientGroup) {
      final groups = context.read<ClientGroupProvider>();
      success = isEditing
          ? groups.updateGroup(_editingGroupId!, value, _selectedClientIds.toList())
          : groups.addGroup(value, _selectedClientIds.toList());
    } else {
      final catalog = context.read<CatalogProvider>();
      switch (widget.type) {
        case CatalogValueType.category:
          success = isEditing ? catalog.updateTag(oldValue!, value) : catalog.addTag(value);
          break;
        case CatalogValueType.brand:
          success = isEditing ? catalog.updateBrand(oldValue!, value) : catalog.addBrand(value);
          break;
        case CatalogValueType.distributor:
          success = isEditing
              ? catalog.updateDistributor(oldValue!, value)
              : catalog.addDistributor(value);
          break;
        case CatalogValueType.clientGroup:
          success = false;
          break;
      }
    }

    if (!success) {
      AppAlert.show(
        context,
        _isClientGroup && _selectedClientIds.isEmpty
            ? 'Selecciona al menos un cliente para crear el grupo.'
            : 'No se pudo guardar el $_singular.',
        title: 'No se pudo guardar',
        type: AppAlertType.warning,
      );
      return;
    }

    if (isEditing && oldValue != value && !_isClientGroup) {
      final products = context.read<ProductProvider>();
      switch (widget.type) {
        case CatalogValueType.category:
          products.renameCategoryReferences(oldValue, value);
          break;
        case CatalogValueType.brand:
          products.renameBrandReferences(oldValue, value);
          break;
        case CatalogValueType.distributor:
          products.renameDistributorReferences(oldValue, value);
          break;
        case CatalogValueType.clientGroup:
          break;
      }
    }

    AppAlert.show(
      context,
      isEditing
          ? 'El $_singular se actualizó correctamente.'
          : 'El $_singular se creó correctamente.',
      title: isEditing
          ? '${_capitalize(_singular)} actualizado'
          : '${_capitalize(_singular)} creado',
      type: AppAlertType.success,
    );

    setState(() {
      _editingName = null;
      _editingGroupId = null;
      _selectedClientIds.clear();
      _controller.clear();
    });
  }

  void _startEdit(String value) {
    setState(() {
      _editingName = value;
      _controller.text = value;
      _controller.selection = TextSelection.collapsed(offset: value.length);
      if (_isClientGroup) {
        final group = context.read<ClientGroupProvider>().groups.firstWhere(
              (item) => item.name == value,
            );
        _editingGroupId = group.id;
        _selectedClientIds
          ..clear()
          ..addAll(group.clientIds);
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingName = null;
      _editingGroupId = null;
      _selectedClientIds.clear();
      _controller.clear();
    });
  }

  Future<void> _delete(String value) async {
    final confirmed = await AppConfirmDialog.delete(context, itemName: 'este $_singular');
    if (!confirmed || !mounted) return;

    bool success;
    if (_isClientGroup) {
      final group = context.read<ClientGroupProvider>().groups.firstWhere((item) => item.name == value);
      success = context.read<ClientGroupProvider>().removeGroup(group.id);
    } else {
      final catalog = context.read<CatalogProvider>();
      switch (widget.type) {
        case CatalogValueType.category:
          success = catalog.removeTag(value);
          break;
        case CatalogValueType.brand:
          success = catalog.removeBrand(value);
          break;
        case CatalogValueType.distributor:
          success = catalog.removeDistributor(value);
          break;
        case CatalogValueType.clientGroup:
          success = false;
          break;
      }
    }

    if (!success) return;
    if (_editingName?.toLowerCase() == value.toLowerCase()) _cancelEdit();

    AppAlert.show(
      context,
      'El $_singular se eliminó correctamente.',
      title: '${_capitalize(_singular)} eliminado',
      type: AppAlertType.success,
    );
  }

  String _capitalize(String value) => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = _values(context);
    final clients = _isClientGroup ? context.watch<CatalogProvider>().clients : const [];

    return Center(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
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
                      hintText: 'Nombre del $_singular',
                      filled: true,
                      fillColor: AppColors.inputBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _editing ? 'Guardar cambios' : 'Agregar',
                  onPressed: _save,
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  icon: Icon(_editing ? Icons.check : Icons.add),
                ),
                if (_editing) IconButton(tooltip: 'Cancelar edición', onPressed: _cancelEdit, icon: const Icon(Icons.close)),
              ],
            ),
            if (_isClientGroup) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Clientes del grupo', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(color: AppColors.inputBackground, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.border)),
                child: clients.isEmpty
                    ? const Padding(padding: EdgeInsets.all(16), child: Text('Todavía no hay clientes creados.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: clients.length,
                        itemBuilder: (_, index) {
                          final client = clients[index];
                          final currentGroup = context.read<ClientGroupProvider>().groupForClient(client.id);
                          final belongsToOtherGroup = currentGroup != null && currentGroup.id != _editingGroupId;
                          final selected = _selectedClientIds.contains(client.id);
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            enabled: !belongsToOtherGroup,
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _selectedClientIds.add(client.id);
                              } else {
                                _selectedClientIds.remove(client.id);
                              }
                            }),
                            title: Text(client.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                            subtitle: belongsToOtherGroup ? const Text('Ya pertenece a otro grupo', style: TextStyle(fontSize: 9)) : null,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          );
                        },
                      ),
              ),
            ],
            const SizedBox(height: 16),
            if (values.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text('Todavía no hay ${_title.toLowerCase()} creados.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: values.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final value = values[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_icon, color: AppColors.primary, size: 20),
                      title: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined, size: 18), color: AppColors.primary, onPressed: () => _startEdit(value)),
                          IconButton(tooltip: 'Eliminar', icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.dangerRed), onPressed: () => _delete(value)),
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
