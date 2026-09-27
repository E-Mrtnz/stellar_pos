import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_archive/flutter_archive.dart';

import 'package:stellar_pos/core/data/storage/local_storage.dart';

class BackupResult {
  final String filePath;
  final int fileCount;
  final int sizeBytes;

  const BackupResult({
    required this.filePath,
    required this.fileCount,
    required this.sizeBytes,
  });
}

class DatabaseBackupService {
  const DatabaseBackupService._();

  static Future<String?> selectDestinationDirectory() {
    return FilePicker.getDirectoryPath(
      dialogTitle: 'Selecciona dónde guardar la copia de seguridad',
    );
  }

  static Future<BackupResult> createBackup({
    required String destinationDirectory,
    void Function(double progress)? onProgress,
  }) async {
    await LocalStorage.flush();

    final sourceDirectory = Directory(
      await LocalStorage.databaseDirectoryPath(),
    );
    if (!await sourceDirectory.exists()) {
      throw StateError('No se encontró el almacenamiento local de STELLAR POS.');
    }

    final hiveFiles = sourceDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.hive'))
        .toList(growable: false);

    if (hiveFiles.isEmpty) {
      throw StateError('No se encontraron archivos de base de datos para respaldar.');
    }

    final destination = Directory(destinationDirectory);
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    var zipFile = File(
      '${destination.path}/stellar_pos_backup_$stamp.zip',
    );
    var suffix = 1;
    while (await zipFile.exists()) {
      zipFile = File(
        '${destination.path}/stellar_pos_backup_${stamp}_$suffix.zip',
      );
      suffix++;
    }

    await ZipFile.createFromFiles(
      sourceDir: sourceDirectory,
      files: hiveFiles,
      zipFile: zipFile,
      includeBaseDirectory: false,
    );

    final size = await zipFile.length();
    onProgress?.call(1);

    return BackupResult(
      filePath: zipFile.path,
      fileCount: hiveFiles.length,
      sizeBytes: size,
    );
  }
}
