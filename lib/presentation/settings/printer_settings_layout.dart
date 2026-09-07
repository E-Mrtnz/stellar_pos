import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/general_settings_provider.dart';
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
                child: _selectedIndex == 0 ? const _GeneralSettingsContent() : const _PrinterContent(),
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
          const Text('Ajustes generales', style: AppTextStyles.brandTitle),
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
    return LayoutBuilder(
      builder: (context, constraints) => ClipRect(
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Transform.translate(
            offset: const Offset(-202, 0),
            child: SizedBox(
              width: constraints.maxWidth + 202,
              height: constraints.maxHeight,
              child: const legacy.PrinterSettingsLayout(),
            ),
          ),
        ),
      ),
    );
  }
}
