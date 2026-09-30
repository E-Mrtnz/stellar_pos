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

  Future<void> _openStoreDialog(BuildContext context) async {
    final provider = context.read<CloudStoreProvider>();
    var createMode = !provider.isConfigured;
    var isWorking = false;
    String? dialogError;

    final nameController =
        TextEditingController(text: provider.storeName ?? '');
    final inviteController = TextEditingController();

    try {
      final completed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final title = createMode ? 'Crear tu tienda' : 'Unirse a una tienda';
            final description = createMode
                ? 'Crea la identidad de tu negocio en la nube. El sistema generará automáticamente un identificador único para la tienda.'
                : 'Introduce el código de invitación que te proporcionó el propietario de una tienda para vincular este dispositivo a sus datos.';

            Future<void> submit() async {
              if (isWorking) return;

              final value = createMode
                  ? nameController.text.trim()
                  : inviteController.text.trim();

              if (value.isEmpty) {
                setDialogState(() {
                  dialogError = createMode
                      ? 'Escribe el nombre de la tienda.'
                      : 'Escribe el código de invitación.';
                });
                return;
              }

              setDialogState(() {
                isWorking = true;
                dialogError = null;
              });

              final success = createMode
                  ? await provider.createStore(value)
                  : await provider.joinStore(value);

              if (!dialogContext.mounted) return;

              if (success) {
                Navigator.of(dialogContext).pop(true);
                return;
              }

              setDialogState(() {
                isWorking = false;
                dialogError = provider.errorMessage ??
                    'No se pudo completar la operación.';
              });
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
              contentPadding: const EdgeInsets.fromLTRB(28, 14, 28, 8),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      createMode
                          ? Icons.add_business_outlined
                          : Icons.link_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.brandTitle.copyWith(fontSize: 20),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller:
                          createMode ? nameController : inviteController,
                      autofocus: true,
                      textCapitalization: createMode
                          ? TextCapitalization.words
                          : TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: createMode
                            ? 'Nombre de la tienda'
                            : 'Código de invitación',
                        hintText: createMode
                            ? 'Ej. Tienda El Edén'
                            : 'Ej. EDEN-4827',
                        prefixIcon: Icon(
                          createMode
                              ? Icons.storefront_outlined
                              : Icons.vpn_key_outlined,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.dangerRed,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: isWorking
                            ? null
                            : () {
                                setDialogState(() {
                                  createMode = !createMode;
                                  dialogError = null;
                                  if (!createMode) {
                                    inviteController.clear();
                                  }
                                });
                              },
                        child: Text(
                          createMode
                              ? '¿Ya tienes una tienda? Usa un código de invitación'
                              : '¿Quieres crear una tienda nueva?',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isWorking
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: isWorking ? null : submit,
                  icon: isWorking
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          createMode
                              ? Icons.add_business_outlined
                              : Icons.link_outlined,
                          size: 18,
                        ),
                  label: Text(createMode ? 'Crear tienda' : 'Unirse a tienda'),
                ),
              ],
            );
          },
        ),
      );

      if (completed == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              createMode
                  ? 'La tienda fue creada correctamente.'
                  : 'El dispositivo quedó vinculado a la tienda.',
            ),
          ),
        );
      }
    } finally {
      nameController.dispose();
      inviteController.dispose();
    }
  }

  Future<void> _manageStore(BuildContext context) async {
    final provider = context.read<CloudStoreProvider>();
    final nameController =
        TextEditingController(text: provider.storeName ?? '');

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final saving = provider.isSaving;

            Future<void> saveName() async {
              if (saving) return;
              if (nameController.text.trim().isEmpty) return;

              final success =
                  await provider.renameStore(nameController.text.trim());
              if (!dialogContext.mounted) return;

              if (success) {
                setDialogState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nombre de la tienda actualizado.'),
                  ),
                );
              }
            }

            Future<void> changeCode() async {
              if (saving) return;

              final confirmed = await showDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) => AlertDialog(
                  title: const Text('Cambiar código de invitación'),
                  content: const Text(
                    'El código actual dejará de funcionar y se generará uno nuevo. Los dispositivos que ya están vinculados no se verán afectados.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(confirmContext).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(confirmContext).pop(true),
                      child: const Text('Generar nuevo'),
                    ),
                  ],
                ),
              );

              if (confirmed != true || !dialogContext.mounted) return;

              final success = await provider.rotateInviteCode();
              if (!dialogContext.mounted) return;

              if (success) {
                setDialogState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Se generó un nuevo código de invitación.'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Administrar tienda'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la tienda',
                        prefixIcon: Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Código de invitación',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.inviteCode ?? 'Sin código',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: saving ? null : changeCode,
                            child: const Text('Cambiar'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Comparte este código únicamente con dispositivos que deban acceder a esta tienda.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'ID interno: ' + (provider.storeId ?? 'No disponible'),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (provider.errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        provider.errorMessage!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.dangerRed,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cerrar'),
                ),
                FilledButton(
                  onPressed: saving ? null : saveName,
                  child: const Text('Guardar cambios'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      nameController.dispose();
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
                  child: const Icon(
                    Icons.cloud_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tienda y sincronización en la nube',
                        style: AppTextStyles.sectionTitle,
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Crea una tienda o vincula este dispositivo a una tienda existente para compartir sus datos en la nube.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    configured
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    size: 22,
                    color: configured
                        ? AppColors.successGreen
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: configured
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cloudStore.storeName ?? 'Tienda configurada',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                cloudStore.inviteCode == null
                                    ? 'Tienda vinculada a la nube.'
                                    : 'Código para vincular otro dispositivo: ' +
                                        cloudStore.inviteCode!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          )
                        : const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Este dispositivo aún no está vinculado a una tienda.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Puedes crear una tienda nueva o unirte a una existente con un código de invitación.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: cloudStore.isSaving
                        ? null
                        : () => configured
                            ? _manageStore(context)
                            : _openStoreDialog(context),
                    icon: Icon(
                      configured
                          ? Icons.manage_accounts_outlined
                          : Icons.add_business_outlined,
                      size: 17,
                    ),
                    label: Text(configured ? 'Administrar' : 'Configurar'),
                  ),
                ],
              ),
            ),
            if (cloudStore.errorMessage != null && !configured) ...[
              const SizedBox(height: 8),
              Text(
                cloudStore.errorMessage!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.dangerRed,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
