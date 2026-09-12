import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/models/client.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/presentation/widgets/app_alert.dart';
import 'package:stellar_pos/presentation/widgets/app_confirm_dialog.dart';

class ClientManagementDialog extends StatefulWidget {
  const ClientManagementDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
        context: context,
        barrierColor: AppColors.overlayBackground,
        builder: (_) => const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClientManagementDialog(),
        ),
      );

  @override
  State<ClientManagementDialog> createState() => _ClientManagementDialogState();
}

class _ClientManagementDialogState extends State<ClientManagementDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _searchController = TextEditingController();
  String? _editingId;
  Timer? _searchDebounce;

  bool get _editing => _editingId != null;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _editingId = null;
    _nameController.clear();
    _phoneController.clear();
    _addressController.clear();
  }

  void _edit(Client client) {
    setState(() {
      _editingId = client.id;
      _nameController.text = client.name;
      _phoneController.text = client.phone;
      _addressController.text = client.address;
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppAlert.show(context, 'El nombre del cliente es obligatorio.', title: 'Campo requerido', type: AppAlertType.warning);
      return;
    }

    final catalog = context.read<CatalogProvider>();
    bool saved;
    if (_editing) {
      saved = catalog.updateClient(Client(
        id: _editingId!,
        name: name,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      ));
    } else {
      final before = catalog.clients.length;
      catalog.addClient(Client(
        id: '',
        name: name,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      ));
      saved = catalog.clients.length > before;
    }

    if (!saved) {
      AppAlert.show(context, 'No se pudo guardar el cliente. Verifica que el nombre no esté repetido.', title: 'No se pudo guardar', type: AppAlertType.warning);
      return;
    }

    setState(_clearForm);
  }

  Future<void> _delete(Client client) async {
    final confirmed = await AppConfirmDialog.delete(context, itemName: 'este cliente');
    if (!confirmed || !mounted) return;
    context.read<CatalogProvider>().removeClient(client.id);
    if (_editingId == client.id) setState(_clearForm);
  }

  @override
  Widget build(BuildContext context) {
    final clients = context.watch<CatalogProvider>().clients;
    final query = _searchController.text.trim().toLowerCase();
    final filtered = clients.where((client) {
      if (query.isEmpty) return true;
      return client.name.toLowerCase().contains(query) || client.phone.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimensions.dialogRadius),
            border: Border.all(color: AppColors.border),
            boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Expanded(child: Text('Clientes', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold))),
                IconButton(tooltip: 'Cerrar', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 10),
              _field(_nameController, 'Nombre del cliente'),
              const SizedBox(height: 8),
              _field(_phoneController, 'Número de teléfono', keyboardType: TextInputType.phone),
              const SizedBox(height: 8),
              _field(_addressController, 'Dirección', keyboardType: TextInputType.streetAddress, maxLines: 2),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size.fromHeight(42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.buttonRadius))), child: Text(_editing ? 'Guardar cambios' : 'Crear Cliente'))),
                if (_editing) ...[
                  const SizedBox(width: 8),
                  IconButton(tooltip: 'Cancelar edición', onPressed: () => setState(_clearForm), icon: const Icon(Icons.close, color: AppColors.textSecondary)),
                ],
              ]),
              const SizedBox(height: 18),
              const Divider(color: AppColors.border),
              const SizedBox(height: 12),
              Row(children: [const Expanded(child: Text('Clientes creados', style: AppTextStyles.sectionTitle)), Text('${filtered.length}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11))]),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (_) { _searchDebounce?.cancel(); _searchDebounce = Timer(const Duration(milliseconds: 120), () { if (mounted) setState(() {}); }); },
                decoration: InputDecoration(isDense: true, hintText: 'Buscar cliente...', prefixIcon: const Icon(Icons.search, size: 18), filled: true, fillColor: AppColors.inputBackground, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border))),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: filtered.isEmpty
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 22), child: Center(child: Text('Todavía no hay clientes creados.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (_, index) {
                          final client = filtered[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.primary.withAlpha(18), shape: BoxShape.circle), child: const Icon(Icons.person_outline, size: 18, color: AppColors.primary)),
                            title: Text(client.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            subtitle: Text([client.phone, client.address].where((value) => value.trim().isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(tooltip: 'Editar', onPressed: () => _edit(client), icon: const Icon(Icons.edit_outlined, size: 18), color: AppColors.primary), IconButton(tooltip: 'Eliminar', onPressed: () => _delete(client), icon: const Icon(Icons.delete_outline, size: 19), color: AppColors.dangerRed)]),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint, {TextInputType? keyboardType, int maxLines = 1}) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        decoration: InputDecoration(isDense: true, hintText: hint, hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), filled: true, fillColor: AppColors.inputBackground, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border))),
      );
}
