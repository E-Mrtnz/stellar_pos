import 'package:flutter/material.dart';

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

  Future<void> _createBackup() async {
    if (_isCreating) return;

    final destination = await DatabaseBackupService.selectDestinationDirectory();
    if (!mounted || destination == null || destination.isEmpty) return;

    setState(() {
      _isCreating = true;
      _progress = 0;
      _lastBackupPath = null;
    });

    try {
      final result = await DatabaseBackupService.createBackup(
        destinationDirectory: destination,
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

      _showMessage(
        'Copia creada correctamente. Se incluyeron ${result.fileCount} archivos de base de datos (${_formatBytes(result.sizeBytes)}).',
        success: true,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      _showMessage(
        error.toString().replaceFirst('Bad state: ', ''),
        success: false,
      );
    }
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
    if (bytes < 1024) return '$bytes B';
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
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.pagePadding * 2),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
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
              const Text(
                'Crea una copia comprimida de la base de datos local de STELLAR POS.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.largeCardRadius),
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
                    const Row(
                      children: [
                        Icon(
                          Icons.backup_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Crear copia de seguridad',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'STELLAR POS incluirá únicamente los archivos .hive de Hive CE. Los archivos .lock no se incluyen en el respaldo.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _isCreating ? null : _createBackup,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: Text(
                          _isCreating
                              ? 'Creando copia...'
                              : 'Seleccionar ubicación y crear backup',
                        ),
                      ),
                    ),
                    if (_isCreating) ...[
                      const SizedBox(height: 20),
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 8),
                      Text(
                        'Comprimiendo base de datos... ${(_progress * 100).toStringAsFixed(0)}%',
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
                          borderRadius: BorderRadius.circular(10),
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
                                'Backup guardado en:\n$_lastBackupPath',
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
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 12),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Recomendación: guarda las copias fuera del repositorio principal de STELLAR POS. Más adelante configuraremos el almacenamiento externo privado de estos backups.',
                            style: TextStyle(
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
