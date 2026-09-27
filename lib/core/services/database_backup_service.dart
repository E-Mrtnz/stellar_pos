import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/data/storage/local_storage.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
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

class BackupFileSelection {
  final String name;
  final String? path;
  final Uint8List? bytes;

  const BackupFileSelection({
    required this.name,
    this.path,
    this.bytes,
  });
}

class DatabaseBackupService {
  const DatabaseBackupService._();

  static Future<String?> selectDestinationDirectory() {
    if (kIsWeb) return Future<String?>.value(null);
    return FilePicker.getDirectoryPath(
      dialogTitle: 'Selecciona dónde guardar la copia de seguridad',
    );
  }

  static Future<BackupFileSelection?> selectBackupFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Selecciona la copia de seguridad que deseas restaurar',
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: false,
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) return null;

    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError(
          'No fue posible leer el backup seleccionado en el navegador.',
        );
      }
      return BackupFileSelection(
        name: file.name,
        bytes: bytes,
      );
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      throw StateError('No fue posible obtener la ruta del backup seleccionado.');
    }
    return BackupFileSelection(
      name: file.name,
      path: path,
    );
  }

  static Future<BackupResult> createBackup({
    required String destinationDirectory,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      return _createWebBackup(onProgress: onProgress);
    }

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
    required BackupFileSelection backupFile,
  }) async {
    if (kIsWeb) {
      final bytes = backupFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError(
          'El backup seleccionado no contiene datos que puedan restaurarse en Web.',
        );
      }
      return _restoreWebBackup(
        backupFileName: backupFile.name,
        bytes: bytes,
      );
    }

    final backupFilePath = backupFile.path;
    if (backupFilePath == null || backupFilePath.isEmpty) {
      throw StateError('No se encontró la ruta del backup seleccionado.');
    }
    final backupFileOnDisk = File(backupFilePath);
    if (!await backupFileOnDisk.exists()) {
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
      try {
        await safetyDirectory.delete(recursive: true);
      } catch (_) {}
      try {
        await restoreDirectory.delete(recursive: true);
      } catch (_) {}
    }
  }

  static const List<String> _webBackupBoxNames = <String>[
    StorageBoxes.products,
    StorageBoxes.clients,
    StorageBoxes.providerRoutes,
    StorageBoxes.providerCatalog,
    StorageBoxes.sales,
    StorageBoxes.purchases,
    StorageBoxes.debtAccounts,
    StorageBoxes.debtMovements,
    StorageBoxes.clientGroups,
    StorageBoxes.electronicBalanceAccounts,
    StorageBoxes.electronicBalanceTransactions,
  ];

  static Future<BackupResult> _createWebBackup({
    void Function(double progress)? onProgress,
  }) async {
    await LocalStorage.flush();
    onProgress?.call(0.05);

    final archive = Archive();
    final manifest = <String, dynamic>{
      'format': 'stellar_pos_web_backup',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'boxes': _webBackupBoxNames,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile(
        'manifest.json',
        manifestBytes.length,
        manifestBytes,
      ),
    );

    var totalEntries = 0;
    for (var index = 0; index < _webBackupBoxNames.length; index++) {
      final boxName = _webBackupBoxNames[index];
      final box = await LocalStorage.openBox(boxName);
      final entries = <Map<String, dynamic>>[];

      for (final entry in box.toMap().entries) {
        entries.add(<String, dynamic>{
          'key': entry.key,
          'value': entry.value,
        });
      }

      totalEntries += entries.length;
      final payload = <String, dynamic>{
        'box': boxName,
        'entries': entries,
      };
      final payloadBytes = utf8.encode(jsonEncode(payload));
      archive.addFile(
        ArchiveFile(
          '$boxName.json',
          payloadBytes.length,
          payloadBytes,
        ),
      );

      onProgress?.call(0.1 + ((index + 1) / _webBackupBoxNames.length) * 0.65);
      await Future<void>.delayed(Duration.zero);
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('No fue posible generar el archivo ZIP del backup Web.');
    }

    final bytes = Uint8List.fromList(encoded);
    final stamp = _backupStamp();
    final fileName = 'stellar_pos_web_backup_$stamp';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'zip',
      mimeType: MimeType.other,
    );

    onProgress?.call(1);
    return BackupResult(
      filePath: '$fileName.zip',
      fileCount: totalEntries,
      sizeBytes: bytes.length,
    );
  }

  static Future<RestoreResult> _restoreWebBackup({
    required String backupFileName,
    required Uint8List bytes,
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final manifestEntry = archive.firstWhere(
      (entry) => entry.name == 'manifest.json' && entry.isFile,
      orElse: () => throw StateError(
        'El archivo seleccionado no es un backup Web válido de STELLAR POS.',
      ),
    );

    final manifest = jsonDecode(utf8.decode(manifestEntry.content));
    if (manifest is! Map ||
        manifest['format'] != 'stellar_pos_web_backup' ||
        manifest['version'] != 1) {
      throw StateError(
        'El backup seleccionado no tiene un formato compatible con la versión Web de STELLAR POS.',
      );
    }

    final safetySnapshot = await _snapshotWebData();
    final safetySize = utf8.encode(jsonEncode(safetySnapshot)).length;

    try {
      final restoredData = <String, Map<dynamic, dynamic>>{};
      var restoredEntries = 0;

      for (final boxName in _webBackupBoxNames) {
        final entry = archive.firstWhere(
          (item) => item.name == '$boxName.json' && item.isFile,
          orElse: () => throw StateError(
            'El backup está incompleto: falta la caja $boxName.',
          ),
        );

        final payload = jsonDecode(utf8.decode(entry.content));
        if (payload is! Map || payload['box'] != boxName) {
          throw StateError(
            'El backup contiene datos inválidos para la caja $boxName.',
          );
        }

        final rawEntries = payload['entries'];
        if (rawEntries is! List) {
          throw StateError(
            'El backup contiene una estructura inválida para la caja $boxName.',
          );
        }

        final boxData = <dynamic, dynamic>{};
        for (final rawEntry in rawEntries) {
          if (rawEntry is! Map ||
              !rawEntry.containsKey('key') ||
              !rawEntry.containsKey('value')) {
            throw StateError(
              'El backup contiene un registro inválido en la caja $boxName.',
            );
          }
          boxData[rawEntry['key']] = rawEntry['value'];
        }

        restoredData[boxName] = boxData;
        restoredEntries += boxData.length;
        await Future<void>.delayed(Duration.zero);
      }

      for (final boxName in _webBackupBoxNames) {
        final box = await LocalStorage.openBox(boxName);
        await box.clear();
        final data = restoredData[boxName]!;
        if (data.isNotEmpty) {
          await box.putAll(data);
        }
        await Future<void>.delayed(Duration.zero);
      }

      return RestoreResult(
        backupFilePath: backupFileName,
        fileCount: restoredEntries,
        safetyBackupSizeBytes: safetySize,
      );
    } catch (error) {
      try {
        await _restoreWebSnapshot(safetySnapshot);
      } catch (rollbackError) {
        throw StateError(
          'No se pudo restaurar el backup Web y tampoco fue posible recuperar automáticamente los datos anteriores. Error de restauración: $error. Error de recuperación: $rollbackError',
        );
      }
      rethrow;
    }
  }

  static Future<Map<String, Map<dynamic, dynamic>>> _snapshotWebData() async {
    final snapshot = <String, Map<dynamic, dynamic>>{};
    for (final boxName in _webBackupBoxNames) {
      final box = await LocalStorage.openBox(boxName);
      snapshot[boxName] = Map<dynamic, dynamic>.from(box.toMap());
    }
    return snapshot;
  }

  static Future<void> _restoreWebSnapshot(
    Map<String, Map<dynamic, dynamic>> snapshot,
  ) async {
    for (final boxName in _webBackupBoxNames) {
      final box = await LocalStorage.openBox(boxName);
      await box.clear();
      final data = snapshot[boxName];
      if (data != null && data.isNotEmpty) {
        await box.putAll(data);
      }
    }
  }

  static String _backupStamp() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
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
        final archive = ZipDecoder().decodeBuffer(input, verify: true);
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
