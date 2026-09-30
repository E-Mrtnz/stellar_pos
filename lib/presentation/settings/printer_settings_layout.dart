import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_engine.dart';
import 'package:stellar_pos/core/providers/general_settings_provider.dart';
import 'package:stellar_pos/core/providers/cloud_store_provider.dart';
import 'package:stellar_pos/core/providers/cloud_access_provider.dart';
import 'package:stellar_pos/presentation/settings/store_access_dialog.dart';
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
                      : _selectedIndex == 2
                      ? const DatabaseBackupLayout()
                      : const _CloudStoreSettingsContent(),
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
        _menuItem(3, Icons.cloud_outlined, 'Tienda y nube'),
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

class _CloudStoreSettingsContent extends StatelessWidget {
  const _CloudStoreSettingsContent();

  Future<void> _openStoreDialog(BuildContext context, {bool? initialCreateMode}) async {
    final provider = context.read<CloudStoreProvider>();
    var createMode = initialCreateMode ?? !provider.isConfigured;
    var isWorking = false;
    String? dialogError;

    final nameController = TextEditingController(text: provider.storeName ?? '');
    final emailController = TextEditingController(text: provider.ownerEmail ?? '');
    final userNameController = TextEditingController();
    final inviteController = TextEditingController();

    try {
      final completed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final title = createMode ? 'Crear tu tienda' : 'Unirse a una tienda';
            final description = createMode
                ? 'Define la identidad de tu negocio. El identificador interno se generará automáticamente.'
                : 'Registra tu nombre y utiliza el código que te proporcionó el propietario.';

            Future<void> submit() async {
              if (isWorking) return;

              if (createMode) {
                if (nameController.text.trim().isEmpty) {
                  setDialogState(() => dialogError = 'Escribe el nombre de la tienda.');
                  return;
                }
                if (emailController.text.trim().isEmpty ||
                    !emailController.text.contains('@')) {
                  setDialogState(() => dialogError = 'Escribe un correo válido para el propietario.');
                  return;
                }
              } else {
                if (userNameController.text.trim().isEmpty) {
                  setDialogState(() => dialogError = 'Escribe el nombre del usuario.');
                  return;
                }
                if (inviteController.text.trim().isEmpty) {
                  setDialogState(() => dialogError = 'Escribe el código de invitación.');
                  return;
                }
              }

              setDialogState(() {
                isWorking = true;
                dialogError = null;
              });

              final success = createMode
                  ? await provider.createStore(
                      nameController.text.trim(),
                      emailController.text.trim(),
                    )
                  : await provider.joinStore(
                      userNameController.text.trim(),
                      inviteController.text.trim(),
                    );

              if (!dialogContext.mounted) return;

              if (success) {
                await context.read<CloudAccessProvider>().load();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
                return;
              }

              setDialogState(() {
                isWorking = false;
                dialogError = provider.errorMessage ?? 'No se pudo completar la operación.';
              });
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: SizedBox(
                width: 540,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              createMode ? Icons.add_business_outlined : Icons.link_outlined,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: AppTextStyles.brandTitle.copyWith(fontSize: 20)),
                                const SizedBox(height: 3),
                                Text(
                                  description,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.35,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (createMode) ...[
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la tienda',
                            prefixIcon: Icon(Icons.storefront_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo del propietario',
                            hintText: 'propietario@ejemplo.com',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => submit(),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Se utilizará como dato de contacto y podrá servir posteriormente para autenticación, recuperación y notificaciones.',
                          style: TextStyle(fontSize: 10.5, height: 1.35, color: AppColors.textSecondary),
                        ),
                      ] else ...[
                        TextField(
                          controller: userNameController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Tu nombre',
                            hintText: 'Ej. Samuel',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: inviteController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Código de invitación',
                            hintText: 'Ej. EDEN-4827',
                            prefixIcon: Icon(Icons.vpn_key_outlined),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => submit(),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tu nombre será visible para la administración. Tu User ID y este dispositivo se registrarán por separado.',
                          style: TextStyle(fontSize: 10.5, height: 1.35, color: AppColors.textSecondary),
                        ),
                      ],
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: AppColors.dangerRed.withAlpha(10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.dangerRed.withAlpha(35)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 17, color: AppColors.dangerRed),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.35,
                                    color: AppColors.dangerRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: isWorking
                              ? null
                              : () {
                                  setDialogState(() {
                                    createMode = !createMode;
                                    dialogError = null;
                                  });
                                },
                          child: Text(
                            createMode
                                ? '¿Ya tienes una tienda? Únete con un código de invitación'
                                : '¿Quieres crear una tienda nueva?',
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isWorking ? null : () => Navigator.of(dialogContext).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: isWorking ? null : submit,
                            icon: isWorking
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(
                                    createMode ? Icons.add_business_outlined : Icons.link_outlined,
                                    size: 18,
                                  ),
                            label: Text(createMode ? 'Crear tienda' : 'Unirse a tienda'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
                  : 'El usuario y su dispositivo quedaron registrados.',
            ),
          ),
        );
      }
    } finally {
      nameController.dispose();
      emailController.dispose();
      userNameController.dispose();
      inviteController.dispose();
    }
  }

  Future<void> _forceUploadAll(BuildContext context) async {
    final provider = context.read<CloudStoreProvider>();
    await provider.forceUploadAll();
    if (!context.mounted) return;

    final result = provider.lastSyncResult;
    final success = result != null && result.failed == 0;
    final errors = result?.errors ?? const <String>[];
    final fatalError = provider.errorMessage;
    final summary = result == null
        ? 'No se pudo completar la carga.\n' +
            (fatalError ?? 'La operación terminó sin un resultado.')
        : 'Registros procesados: ' + result.migrated.toString() + '\n'
            'Subidos: ' + result.uploaded.toString() + '\n'
            'Descargados: ' + result.downloaded.toString() + '\n'
            'Eliminados: ' + result.deleted.toString() + '\n'
            'Fallos: ' + result.failed.toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(success ? 'Carga a la nube completada' : 'Carga a la nube con problemas'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary),
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Errores detectados:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...errors.take(8).map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        error,
                        style: const TextStyle(fontSize: 11, color: AppColors.dangerRed),
                      ),
                    ),
                  ),
                  if (errors.length > 8)
                    Text(
                      'Se ocultaron ' + (errors.length - 8).toString() + ' errores adicionales. Revisa la consola de depuración para el detalle completo.',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAccessDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const StoreAccessDialog(),
    );
  }

  Future<void> _manageStore(BuildContext context) async {
    final provider = context.read<CloudStoreProvider>();
    final nameController = TextEditingController(text: provider.storeName ?? '');
    final emailController = TextEditingController(text: provider.ownerEmail ?? '');

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final saving = provider.isSaving;

            Future<void> saveChanges() async {
              if (saving) return;
              if (nameController.text.trim().isEmpty ||
                  emailController.text.trim().isEmpty ||
                  !emailController.text.contains('@')) {
                return;
              }

              final nameSuccess = await provider.renameStore(nameController.text.trim());
              final emailSuccess = await provider.updateOwnerEmail(emailController.text.trim());
              if (!dialogContext.mounted) return;

              if (nameSuccess && emailSuccess) {
                setDialogState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cambios guardados correctamente.')),
                );
              }
            }

            Future<void> copyCode() async {
              final code = provider.inviteCode;
              if (code == null) return;
              await Clipboard.setData(ClipboardData(text: code));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Código de invitación copiado.')),
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
                  const SnackBar(content: Text('Nuevo código de invitación generado.')),
                );
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: SizedBox(
                width: 560,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.storefront_outlined, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 13),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Administrar tienda', style: AppTextStyles.brandTitle),
                                SizedBox(height: 3),
                                Text(
                                  'Actualiza la identidad visible y controla el acceso mediante el código de invitación.',
                                  style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la tienda',
                          prefixIcon: Icon(Icons.storefront_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo del propietario',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key_outlined, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Código de invitación',
                                    style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    provider.inviteCode ?? 'Sin código',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copiar código',
                              onPressed: saving ? null : copyCode,
                              icon: const Icon(Icons.copy_rounded),
                            ),
                            IconButton(
                              tooltip: 'Cambiar código',
                              onPressed: saving ? null : changeCode,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Comparte este código solo con las personas o dispositivos que deban acceder a esta tienda.',
                        style: TextStyle(fontSize: 10.5, height: 1.35, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.fingerprint_rounded, size: 17, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Store ID: ' + (provider.storeId ?? 'No disponible'),
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (provider.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          provider.errorMessage!,
                          style: const TextStyle(fontSize: 11, color: AppColors.dangerRed),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cerrar'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: saving ? null : saveChanges,
                            icon: saving
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Guardar cambios'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      nameController.dispose();
      emailController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CloudStoreProvider>(
      builder: (context, cloudStore, _) {
        final configured = cloudStore.isConfigured;
        final access = context.watch<CloudAccessProvider>();

        return Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tienda y nube', style: AppTextStyles.brandTitle),
              const SizedBox(height: 4),
              const Text(
                'Administra la identidad de tu tienda, sus usuarios, dispositivos y sincronización.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: configured
                      ? _buildConfigured(context, cloudStore, access)
                      : _buildUnconfigured(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnconfigured(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cloudHero(
          icon: Icons.cloud_off_outlined,
          title: 'Conecta Stellar POS con una tienda',
          subtitle:
              'Crea una tienda nueva para este negocio o vincula este dispositivo a una tienda que ya existe.',
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _cloudActionCard(
                icon: Icons.add_business_outlined,
                title: 'Crear una tienda',
                description:
                    'Registra el nombre del negocio y el correo del propietario. El Store ID se generará automáticamente.',
                buttonLabel: 'Crear tienda',
                onPressed: () => _openStoreDialog(context, initialCreateMode: true),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _cloudActionCard(
                icon: Icons.link_outlined,
                title: 'Unirse a una tienda',
                description:
                    'Usa el código de invitación que te proporcionó el propietario para registrar este usuario y dispositivo.',
                buttonLabel: 'Unirme a una tienda',
                onPressed: () => _openStoreDialog(context, initialCreateMode: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfigured(
    BuildContext context,
    CloudStoreProvider cloudStore,
    CloudAccessProvider access,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cloudHero(
          icon: Icons.cloud_done_outlined,
          title: cloudStore.storeName ?? 'Tienda configurada',
          subtitle:
              'Este dispositivo está vinculado a la tienda y puede sincronizar sus datos con la nube.',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.successGreen.withAlpha(50)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: AppColors.successGreen),
                SizedBox(width: 6),
                Text(
                  'Conectada',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.successGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _cloudInfoCard(
                icon: Icons.storefront_outlined,
                title: 'Tienda',
                value: cloudStore.storeName ?? 'Sin nombre',
                detail: 'ID: ' + (cloudStore.storeId ?? 'No disponible'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _cloudInfoCard(
                icon: Icons.person_outline,
                title: 'Propietario',
                value: cloudStore.ownerEmail ?? 'Sin correo',
                detail: 'Correo de contacto y administración',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _cloudInviteInfoCard(
                context: context,
                code: cloudStore.inviteCode ?? 'Sin código',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _cloudSectionCard(
          icon: Icons.cloud_upload_outlined,
          title: 'Sincronización de datos',
          subtitle: 'Fuerza una carga completa de los registros locales de este dispositivo hacia la nube.',
          children: [
            _cloudActionRow(
              icon: Icons.cloud_upload_outlined,
              title: 'Subir todos los datos ahora',
              subtitle: 'Carga productos, ventas, compras, clientes, deudas, proveedores y saldos electrónicos.',
              label: cloudStore.isSaving ? 'Subiendo...' : 'Subir todo',
              onPressed: cloudStore.isSaving ? null : () => _forceUploadAll(context),
            ),
            if (cloudStore.syncProgress != null) ...[
              const SizedBox(height: 8),
              _buildCloudUploadProgress(cloudStore.syncProgress!),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _cloudSectionCard(
          icon: Icons.manage_accounts_outlined,
          title: 'Administración',
          subtitle: 'Gestiona la tienda y controla quién puede acceder a ella.',
          children: [
            _cloudActionRow(
              icon: Icons.storefront_outlined,
              title: 'Administrar tienda',
              subtitle: 'Nombre, correo del propietario y código de invitación.',
              label: 'Administrar',
              onPressed: cloudStore.isSaving ? null : () => _manageStore(context),
            ),
            if (access.canManageUsers)
              _cloudActionRow(
                icon: Icons.groups_outlined,
                title: 'Usuarios y dispositivos',
                subtitle: 'Consulta usuarios, roles, permisos y dispositivos vinculados.',
                label: 'Gestionar',
                onPressed: cloudStore.isSaving ? null : () => _openAccessDialog(context),
              ),
          ],
        ),
        if (cloudStore.errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            cloudStore.errorMessage!,
            style: const TextStyle(fontSize: 11, color: AppColors.dangerRed),
          ),
        ],
      ],
    );
  }

  Widget _cloudHero({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(24),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: AppColors.primary, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.sectionTitle),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _cloudActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  Widget _cloudInviteInfoCard({
    required BuildContext context,
    required String code,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.vpn_key_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Invitación',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copiar código',
                      visualDensity: VisualDensity.compact,
                      onPressed: code == 'Sin código'
                          ? null
                          : () async {
                              await Clipboard.setData(ClipboardData(text: code));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Código de invitación copiado.')),
                                );
                              }
                            },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                const Text(
                  'Código para vincular nuevos dispositivos',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cloudInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required String detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cloudSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 21),
              const SizedBox(width: 9),
              Expanded(child: Text(title, style: AppTextStyles.sectionTitle)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCloudUploadProgress(CloudSyncProgress progress) {
    final current = progress.total <= 0
        ? progress.collection
        : progress.collection + ' · ' +
            progress.processed.toString() +
            '/' +
            progress.total.toString();
    final percent = (progress.overallFraction * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (progress.phase == 'Completado')
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppColors.successGreen,
                )
              else
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progress.phase + ' · ' + current,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                percent.toString() + '%',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress.overallFraction, minHeight: 6),
          ),
          if (progress.failed > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Fallos: ' + progress.failed.toString(),
              style: const TextStyle(fontSize: 10, color: AppColors.dangerRed, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cloudActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: Text(label),
          ),
        ],
      ),
    );
  }
}
