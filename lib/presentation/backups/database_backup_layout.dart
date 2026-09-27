import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:stellar_pos/app.dart';
import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/services/database_backup_service.dart';

class DatabaseBackupLayout extends StatefulWidget {
  const DatabaseBackupLayout({super.key});

  @override
  State<DatabaseBackupLayout> createState() => _DatabaseBackupLayoutState();
}

class _DatabaseBackupLayoutState extends State<DatabaseBackupLayout> {
  bool _isCreating = false;
  double _progress = 0;
  String? _lastBackupPath;
  bool _isRestoring = false;

  Future<void> _createBackup() async {
    if (_isCreating || _isRestoring) return;

    String? destination;
    if (!kIsWeb) {
      destination =
          await DatabaseBackupService.selectDestinationDirectory();
      if (!mounted || destination == null || destination.isEmpty) return;
    }

    setState(() {
      _isCreating = true;
      _progress = 0;
      _lastBackupPath = null;
    });

    try {
      final result = await DatabaseBackupService.createBackup(
        destinationDirectory: destination ?? '',
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress = value.clamp(0, 1).toDouble());
        },
      );

      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _progress = 1;
        _lastBackupPath = result.filePath;
      });

      final message = kIsWeb
          ? 'Backup Web descargado correctamente. Se incluyeron ${result.fileCount} registros (${_formatBytes(result.sizeBytes)}).'
          : 'Copia creada correctamente. Se incluyeron ${result.fileCount} archivos de base de datos (${_formatBytes(result.sizeBytes)}).';

      _showMessage(message, success: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      _showMessage(
        error.toString().replaceFirst('Bad state: ', ''),
        success: false,
      );
    }
  }

  Future<void> _restoreBackup() async {
    if (_isCreating || _isRestoring) return;

    BackupFileSelection? backupFile;
    try {
      backupFile = await DatabaseBackupService.selectBackupFile();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Bad state: ', ''),
        success: false,
      );
      return;
    }

    if (!mounted || backupFile == null) return;

    final confirmed = await _showRestoreConfirmation(backupFile.name);
    if (!confirmed || !mounted) return;

    setState(() {
      _isRestoring = true;
      _lastBackupPath = null;
    });

    try {
      final result = await DatabaseBackupService.restoreBackup(
        backupFile: backupFile,
      );

      if (!mounted) return;
      _showMessage(
        kIsWeb
            ? 'Restauración completada. Se recuperaron ${result.fileCount} registros.'
            : 'Restauración completada. Se recuperaron ${result.fileCount} archivos de base de datos. La aplicación se reiniciará.',
        success: true,
      );

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      runApp(
        AppProviders(
          key: UniqueKey(),
          child: const StellarPosApp(),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      _showMessage(
        error.toString().replaceFirst('Bad state: ', ''),
        success: false,
      );
    }
  }

  Future<bool> _showRestoreConfirmation(String fileName) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowColor,
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.warningOrange.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.restore_rounded,
                              color: AppColors.warningOrange,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                'Confirmar restauración',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.folder_zip_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                fileName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        kIsWeb
                            ? 'Los datos locales actuales serán reemplazados por los contenidos de esta copia. Antes de aplicar el cambio, STELLAR POS guardará una copia temporal en el almacenamiento del navegador para poder revertir el proceso si ocurre un error.'
                            : 'Los archivos .hive actuales serán reemplazados por los contenidos de esta copia. Antes de aplicar el cambio, STELLAR POS creará una copia temporal de seguridad para poder revertir el proceso si ocurre un error.',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              kIsWeb
                                  ? 'La restauración se realizará directamente sobre el almacenamiento local del navegador; no se utilizarán rutas de archivos del sistema.'
                                  : 'La aplicación se reiniciará al finalizar para cargar la información restaurada.',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            icon: const Icon(Icons.restore_rounded, size: 18),
                            label: const Text('Restaurar'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ) ??
        false;
  }

  void _showMessage(String message, {required bool success}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              success ? AppColors.successGreen : AppColors.dangerRed,
        ),
      );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isCreating || _isRestoring;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.pagePadding * 2),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copias de seguridad',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kIsWeb
                    ? 'Protege los datos locales del navegador con una copia descargable.'
                    : 'Crea una copia comprimida de la base de datos local de STELLAR POS.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.largeCardRadius),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.backup_outlined,
                            color: AppColors.primary,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Respaldo de datos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      kIsWeb
                          ? 'En Web, STELLAR POS exportará las cajas de Hive CE desde el almacenamiento del navegador y generará un archivo ZIP descargable.'
                          : 'En escritorio, STELLAR POS incluirá únicamente los archivos .hive de Hive CE. Los archivos .lock no forman parte del respaldo.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isBusy ? null : _createBackup,
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: Text(
                              _isCreating
                                  ? 'Generando backup...'
                                  : kIsWeb
                                      ? 'Crear y descargar backup'
                                      : 'Seleccionar ubicación y crear backup',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isBusy ? null : _restoreBackup,
                            icon: const Icon(Icons.restore_rounded),
                            label: Text(
                              _isRestoring
                                  ? 'Restaurando...'
                                  : 'Seleccionar backup',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isCreating) ...[
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: _progress == 0 ? null : _progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        kIsWeb
                            ? 'Preparando los datos y descargando el archivo...'
                            : 'Comprimiendo la base de datos en segundo plano...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (_isRestoring) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(minHeight: 6),
                      const SizedBox(height: 9),
                      Text(
                        kIsWeb
                            ? 'Validando la copia y restaurando el almacenamiento del navegador...'
                            : 'Restaurando la base de datos de forma segura...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (_lastBackupPath != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppColors.successGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                kIsWeb
                                    ? 'Backup descargado como:\n$_lastBackupPath'
                                    : 'Backup guardado en:$n$$_lastBackupPath',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            kIsWeb
                                ? 'El backup Web se genera desde IndexedDB y no depende de rutas del sistema operativo.'
                                : 'Guarda las copias fuera del repositorio principal de STELLAR POS. Más adelante configuraremos el almacenamiento externo privado de estos backups.',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
