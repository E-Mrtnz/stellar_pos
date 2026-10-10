import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/general_settings_provider.dart';
import 'package:stellar_pos/presentation/backups/database_backup_layout.dart';
import 'package:stellar_pos/presentation/widgets/settings_toggle_tile.dart';
import 'printer_settings_layout_legacy.dart' as legacy;

class PrinterSettingsLayout extends StatefulWidget {
  final VoidCallback? onReturnToHome;

  const PrinterSettingsLayout({super.key, this.onReturnToHome});

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
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: MediaQuery.sizeOf(context).width < 600
            ? _buildMobileSettings()
            : Row(
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

  Widget _buildMobileSettings() {
    final titles = const ['General', 'Impresoras', 'Copias de seguridad'];
    final icons = const [
      Icons.tune_outlined,
      Icons.print_outlined,
      Icons.backup_outlined,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ajustes',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: titles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) => ChoiceChip(
              selected: _selectedIndex == index,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icons[index], size: 17),
                  const SizedBox(width: 7),
                  Text(titles[index]),
                ],
              ),
              onSelected: (_) => setState(() => _selectedIndex = index),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: AppColors.cardBackground,
              child: _selectedIndex == 0
                  ? const _GeneralSettingsContent()
                  : _selectedIndex == 1
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 720,
                            child: _PrinterContent(),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 720,
                            child: DatabaseBackupLayout(),
                          ),
                        ),
            ),
          ),
        ),
      ],
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

                  const SizedBox(height: 22),
                  Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.volume_up_outlined, color: AppColors.primary)),
                    const SizedBox(width: 12),
                    const Text('Sonidos', style: AppTextStyles.sectionTitle),
                  ]),
                  const SizedBox(height: 14),
                  _switchTile('Sonido al escanear correctamente', 'Reproduce un sonido cuando se reconoce un producto.', settings.barcodeSuccessSound, settings.setBarcodeSuccessSound),
                  const SizedBox(height: 8),
                  _switchTile('Sonido de código no encontrado', 'Reproduce una alerta cuando el código no pertenece a un producto.', settings.barcodeErrorSound, settings.setBarcodeErrorSound),
                  const SizedBox(height: 8),
                  _switchTile('Sonido al completar una venta', 'Reproduce una confirmación al registrar la venta.', settings.saleSuccessSound, settings.setSaleSuccessSound),

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
