import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/general_settings_provider.dart';
import 'package:stellar_pos/core/providers/cloud_store_provider.dart';
import 'package:stellar_pos/presentation/backups/database_backup_layout.dart';
import 'package:stellar_pos/presentation/widgets/settings_toggle_tile.dart';
import 'printer_settings_layout_legacy.dart' as legacy;

class PrinterSettingsLayout extends StatefulWidget {
  const PrinterSettingsLayout({super.key});

  @override
  State<PrinterSettingsLayout> createState() => _PrinterSettingsLayoutState();
}

class _PrinterSettingsLayoutState extends State<PrinterSettingsLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GeneralSettingsProvider(),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMenu(),
            const SizedBox(width: AppDimensions.productGridSpacing),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))],
                ),
                clipBehavior: Clip.antiAlias,
                child: _selectedIndex == 0
                      ? const _GeneralSettingsContent()
                      : _selectedIndex == 1
                      ? const _PrinterContent()
                      : const DatabaseBackupLayout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.fromLTRB(10, 8, 10, 10), child: Text('Ajustes', style: AppTextStyles.sectionTitle)),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 8),
        _menuItem(0, Icons.tune_outlined, 'General'),
        _menuItem(1, Icons.print_outlined, 'Impresoras'),
        _menuItem(2, Icons.backup_outlined, 'Copias de seguridad'),
      ]),
    );
  }

  Widget _menuItem(int index, IconData icon, String title) {
    final selected = index == _selectedIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.primary.withAlpha(18) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(children: [
              Icon(icon, size: 19, color: selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.primary : AppColors.textPrimary))),
              if (selected) const Icon(Icons.chevron_right, size: 17, color: AppColors.primary),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GeneralSettingsContent extends StatelessWidget {
  const _GeneralSettingsContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<GeneralSettingsProvider>(
      builder: (context, settings, _) => Padding(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('General', style: AppTextStyles.brandTitle),
          const SizedBox(height: 4),
          const Text('Preferencias básicas de funcionamiento de Stellar POS.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary)),
                    const SizedBox(width: 12),
                    const Text('Inventario', style: AppTextStyles.sectionTitle),
                  ]),
                  const SizedBox(height: 14),
                  _switchTile('Mostrar "Subir inventario"', 'Muestra la herramienta de importación en Inventario.', settings.showInventoryImport, settings.setShowInventoryImport),
                  const SizedBox(height: 8),
                  _switchTile('Mostrar "Descargar inventario"', 'Muestra las opciones para exportar el inventario.', settings.showInventoryExport, settings.setShowInventoryExport),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 18),
                  const _CloudStoreSettingsSection(),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SettingsToggleTile(title: title, subtitle: subtitle, value: value, onChanged: onChanged, icon: Icons.inventory_2_outlined);
  }
}

class _PrinterContent extends StatelessWidget {
  const _PrinterContent();

  @override
  Widget build(BuildContext context) {
    return const legacy.PrinterSettingsContent();
  }
}

class _CloudStoreSettingsSection extends StatelessWidget {
  const _CloudStoreSettingsSection();

  Future<void> _configure(BuildContext context) async {
    final provider = context.read<CloudStoreProvider>();
    final controller = TextEditingController(text: provider.storeId ?? '');
    try {
      final storeId = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Configurar tienda en la nube'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'ID de tienda',
                hintText: 'Ej. tienda-el-eden',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );

      if (storeId == null || storeId.trim().isEmpty || !context.mounted) return;
      final success = await provider.configure(storeId);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'La tienda quedó configurada para sincronización.'
                : (provider.errorMessage ?? 'No se pudo configurar la tienda.'),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CloudStoreProvider>(
      builder: (context, cloudStore, _) {
        final configured = cloudStore.isConfigured;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_outlined, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sincronización en la nube', style: AppTextStyles.sectionTitle),
                      SizedBox(height: 3),
                      Text(
                        'Identifica la tienda cuyos datos puede sincronizar este dispositivo.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    configured ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    size: 20,
                    color: configured ? AppColors.successGreen : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      configured
                          ? 'Tienda configurada: ${cloudStore.storeId}'
                          : 'Sin tienda configurada. El sistema continúa funcionando de forma local.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: cloudStore.isSaving ? null : () => _configure(context),
                    icon: cloudStore.isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.settings_outlined, size: 17),
                    label: Text(configured ? 'Cambiar' : 'Configurar'),
                  ),
                ],
              ),
            ),
            if (cloudStore.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                cloudStore.errorMessage!,
                style: const TextStyle(fontSize: 11, color: AppColors.dangerRed),
              ),
            ],
          ],
        );
      },
    );
  }
}
