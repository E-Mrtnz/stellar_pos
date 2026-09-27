import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';

import 'package:stellar_pos/core/data/storage/local_storage.dart';
import 'package:stellar_pos/core/data/storage/storage_schema.dart';

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

class RestoreResult {
  final String backupFilePath;
  final int fileCount;
  final int safetyBackupSizeBytes;

  const RestoreResult({
    required this.backupFilePath,
    required this.fileCount,
    required this.safetyBackupSizeBytes,
  });
}

class DatabaseBackupService {
  const DatabaseBackupService._();

  static Future<String?> selectDestinationDirectory() {
    return FilePicker.getDirectoryPath(
      dialogTitle: 'Selecciona dónde guardar la copia de seguridad',
    );
  }

  static Future<String?> selectBackupFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Selecciona la copia de seguridad que deseas restaurar',
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: false,
    );
    return result?.files.single.path;
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

    final zipFile = await _nextBackupFile(destination);
    onProgress?.call(0.05);

    final hiveFilePaths = hiveFiles.map((file) => file.path).toList(growable: false);
    final zipFilePath = zipFile.path;

    final result = await Isolate.run<Map<String, dynamic>>(() async {
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);

      for (final filePath in hiveFilePaths) {
        final file = File(filePath);
        await encoder.addFile(file, file.uri.pathSegments.last);
      }

      await encoder.close();

      return <String, dynamic>{
        'filePath': zipFilePath,
        'fileCount': hiveFilePaths.length,
        'sizeBytes': await File(zipFilePath).length(),
      };
    }, debugName: 'stellar-pos-database-backup');

    onProgress?.call(1);

    return BackupResult(
      filePath: result['filePath'] as String,
      fileCount: result['fileCount'] as int,
      sizeBytes: result['sizeBytes'] as int,
    );
  }

  static Future<RestoreResult> restoreBackup({
    required String backupFilePath,
  }) async {
    final backupFile = File(backupFilePath);
    if (!await backupFile.exists()) {
      throw StateError('No se encontró el archivo de backup seleccionado.');
    }
    if (!backupFilePath.toLowerCase().endsWith('.zip')) {
      throw StateError('El archivo seleccionado no es un backup ZIP válido.');
    }

    final databaseDirectory = Directory(
      await LocalStorage.databaseDirectoryPath(),
    );
    final safetyDirectory = await Directory.systemTemp.createTemp(
      'stellar_pos_safety_backup_',
    );
    final restoreDirectory = await Directory.systemTemp.createTemp(
      'stellar_pos_restore_',
    );

    BackupResult? safetyBackup;
    var databaseClosed = false;

    try {
      // First create a rollback point from the database currently in use.
      safetyBackup = await createBackup(
        destinationDirectory: safetyDirectory.path,
      );

      // Decode and validate the selected ZIP before touching the live database.
      final restoredCount = await _extractHiveFiles(
        backupFilePath,
        restoreDirectory.path,
      );
      if (restoredCount <= 0) {
        throw StateError(
          'El backup no contiene archivos .hive válidos para restaurar.',
        );
      }

      await LocalStorage.close();
      databaseClosed = true;

      try {
        await _replaceDatabaseFiles(
          databaseDirectory: databaseDirectory,
          extractedDirectory: restoreDirectory,
        );
        await LocalStorage.initialize();
        await StorageSchema.initialize();
        databaseClosed = false;
      } catch (restoreError) {
        await LocalStorage.close();
        databaseClosed = true;
        try {
          final rollbackDirectory = await Directory.systemTemp.createTemp(
            'stellar_pos_rollback_',
          );
          try {
            await _extractHiveFiles(
              safetyBackup.filePath,
              rollbackDirectory.path,
            );
            await _replaceDatabaseFiles(
              databaseDirectory: databaseDirectory,
              extractedDirectory: rollbackDirectory,
            );
          } finally {
            await rollbackDirectory.delete(recursive: true);
          }
          await LocalStorage.initialize();
          await StorageSchema.initialize();
          databaseClosed = false;
        } catch (rollbackError) {
          throw StateError(
            'No se pudo restaurar el backup seleccionado y tampoco fue posible recuperar automáticamente la base anterior. Error de restauración: $restoreError. Error de recuperación: $rollbackError',
          );
        }
        rethrow;
      }

      return RestoreResult(
        backupFilePath: backupFilePath,
        fileCount: restoredCount,
        safetyBackupSizeBytes: safetyBackup.sizeBytes,
      );
    } finally {
      if (databaseClosed) {
        await LocalStorage.initialize();
      }
      await safetyDirectory.delete(recursive: true).catchError((_) {});
      await restoreDirectory.delete(recursive: true).catchError((_) {});
    }
  }

  static Future<File> _nextBackupFile(Directory destination) async {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    var file = File(
      '${destination.path}/stellar_pos_backup_$stamp.zip',
    );
    var suffix = 1;
    while (await file.exists()) {
      file = File(
        '${destination.path}/stellar_pos_backup_${stamp}_$suffix.zip',
      );
      suffix++;
    }
    return file;
  }

  static Future<int> _extractHiveFiles(
    String backupFilePath,
    String outputDirectory,
  ) async {
    return Isolate.run<int>(() {
      final input = InputFileStream(backupFilePath);
      try {
        final archive = ZipDecoder().decodeStream(input, verify: true);
        var count = 0;

        for (final entry in archive) {
          if (!entry.isFile || entry.isSymbolicLink) {
            throw StateError(
              'El backup contiene una entrada no permitida. Solo se aceptan archivos .hive.',
            );
          }

          final name = entry.name;
          final safeName = RegExp(r'^[^/\\]+\.hive$', caseSensitive: false);
          if (!safeName.hasMatch(name) || name.contains('..')) {
            throw StateError(
              'El backup contiene un nombre de archivo no válido: $name',
            );
          }

          final output = OutputFileStream('$outputDirectory/$name');
          try {
            entry.writeContent(output);
          } finally {
            output.closeSync();
          }
          count++;
        }

        return count;
      } finally {
        input.closeSync();
      }
    }, debugName: 'stellar-pos-restore-extract');
  }

  static Future<void> _replaceDatabaseFiles({
    required Directory databaseDirectory,
    required Directory extractedDirectory,
  }) async {
    if (!await databaseDirectory.exists()) {
      await databaseDirectory.create(recursive: true);
    }

    final currentFiles = databaseDirectory.listSync().whereType<File>();
    for (final file in currentFiles) {
      final lower = file.path.toLowerCase();
      if (lower.endsWith('.hive') || lower.endsWith('.lock')) {
        await file.delete();
      }
    }

    final restoredFiles = extractedDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.hive'))
        .toList(growable: false);
    if (restoredFiles.isEmpty) {
      throw StateError('No se encontraron archivos .hive extraídos.');
    }

    for (final file in restoredFiles) {
      final destination = File(
        '${databaseDirectory.path}/${file.uri.pathSegments.last}',
      );
      await file.copy(destination.path);
    }
  }
}
