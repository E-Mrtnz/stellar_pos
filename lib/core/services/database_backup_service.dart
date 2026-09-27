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

class _UniversalBackupData {
  final Map<String, Map<dynamic, dynamic>> boxes;
  final int fileCount;

  const _UniversalBackupData({
    required this.boxes,
    required this.fileCount,
  });
}

class DatabaseBackupService {
  const DatabaseBackupService._();

  static const List<String> _backupBoxNames = <String>[
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

  static const String _backupFormat = 'stellar_pos_backup';
  static const int _backupFormatVersion = 2;

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
      throw StateError(
        'No fue posible obtener la ruta del backup seleccionado.',
      );
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
    final result = await _createUniversalBackup(
      onProgress: onProgress,
    );

    if (kIsWeb) {
      final stamp = _backupStamp();
      final fileName = 'stellar_pos_backup_$stamp';
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: result.bytes,
        fileExtension: 'zip',
        mimeType: MimeType.other,
      );

      onProgress?.call(1);
      return BackupResult(
        filePath: '$fileName.zip',
        fileCount: result.fileCount,
        sizeBytes: result.bytes.length,
      );
    }

    final destination = Directory(destinationDirectory);
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    final zipFile = await _nextBackupFile(destination);
    await zipFile.writeAsBytes(result.bytes, flush: true);

    onProgress?.call(1);
    return BackupResult(
      filePath: zipFile.path,
      fileCount: result.fileCount,
      sizeBytes: result.bytes.length,
    );
  }

  static Future<RestoreResult> restoreBackup({
    required BackupFileSelection backupFile,
    void Function(double progress, String status)? onProgress,
  }) async {
    final selectedBytes = await _readBackupBytes(backupFile);

    if (!_containsAsciiSequence(
      selectedBytes,
      '"format":"$_backupFormat"',
    )) {
      if (kIsWeb) {
        throw StateError(
          'El archivo seleccionado pertenece al formato antiguo de STELLAR POS o no es un backup universal. En Web solo se pueden restaurar backups universales creados con la versión actual.',
        );
      }
      return _restoreLegacyDesktopBackup(
        backupFile: backupFile,
        onProgress: onProgress,
      );
    }

    return _restoreUniversalBackup(
      backupFileName: backupFile.name,
      bytes: selectedBytes,
      onProgress: onProgress,
    );
  }

  static Future<Uint8List> _readBackupBytes(
    BackupFileSelection backupFile,
  ) async {
    if (kIsWeb) {
      final bytes = backupFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError(
          'El backup seleccionado no contiene datos que puedan restaurarse en Web.',
        );
      }
      return bytes;
    }

    final path = backupFile.path;
    if (path == null || path.isEmpty) {
      throw StateError('No se encontró la ruta del backup seleccionado.');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('No se encontró el archivo de backup seleccionado.');
    }
    if (!path.toLowerCase().endsWith('.zip')) {
      throw StateError('El archivo seleccionado no es un backup ZIP válido.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('El archivo de backup seleccionado está vacío.');
    }
    return bytes;
  }

  static Future<({Uint8List bytes, int fileCount})> _createUniversalBackup({
    void Function(double progress)? onProgress,
  }) async {
    await LocalStorage.flush();
    onProgress?.call(0.04);

    final payloads = <String, List<int>>{};
    var totalEntries = 0;

    final manifest = <String, dynamic>{
      'format': _backupFormat,
      'version': _backupFormatVersion,
      'schemaVersion': StorageSchema.currentVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'platform': _platformName(),
      'boxes': _backupBoxNames,
      'compression': 'none',
    };
    payloads['manifest.json'] = utf8.encode(jsonEncode(manifest));

    for (var index = 0; index < _backupBoxNames.length; index++) {
      final boxName = _backupBoxNames[index];
      final box = await LocalStorage.openBox(boxName);
      final entries = <Map<String, dynamic>>[];

      for (final entry in box.toMap().entries) {
        entries.add(<String, dynamic>{
          'key': _jsonSafeValue(entry.key),
          'value': _jsonSafeValue(entry.value),
        });
      }

      totalEntries += entries.length;
      final payload = <String, dynamic>{
        'box': boxName,
        'entries': entries,
      };
      payloads['$boxName.json'] = utf8.encode(jsonEncode(payload));

      onProgress?.call(
        0.08 + ((index + 1) / _backupBoxNames.length) * 0.42,
      );
      await Future<void>.delayed(Duration.zero);
    }

    final encoded = await _encodeUniversalZip(payloads);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('No fue posible generar el archivo ZIP del backup.');
    }

    return (
      bytes: Uint8List.fromList(encoded),
      fileCount: totalEntries,
    );
  }

  static Future<List<int>?> _encodeUniversalZip(
    Map<String, List<int>> payloads,
  ) async {
    if (kIsWeb) {
      final archive = Archive();
      for (final entry in payloads.entries) {
        archive.addFile(
          ArchiveFile(
            entry.key,
            entry.value.length,
            entry.value,
          )..compress = false,
        );
      }
      return ZipEncoder().encode(archive);
    }

    return Isolate.run<List<int>?>(() {
      final archive = Archive();
      for (final entry in payloads.entries) {
        archive.addFile(
          ArchiveFile(
            entry.key,
            entry.value.length,
            entry.value,
          )..compress = false,
        );
      }
      return ZipEncoder().encode(archive);
    }, debugName: 'stellar-pos-universal-backup');
  }

  static Future<RestoreResult> _restoreUniversalBackup({
    required String backupFileName,
    required Uint8List bytes,
    void Function(double progress, String status)? onProgress,
  }) async {
    Future<void> report(double progress, String status) async {
      onProgress?.call(progress, status);
      await Future<void>.delayed(Duration.zero);
    }

    await report(0.02, 'Preparando la restauración...');
    await report(0.08, 'Comprobando el formato universal del backup...');

    if (!_containsAsciiSequence(
      bytes,
      '"format":"$_backupFormat"',
    )) {
      throw StateError(
        'El archivo seleccionado no es un backup universal de STELLAR POS.',
      );
    }

    await report(0.12, 'Backup universal reconocido. Leyendo el archivo...');
    final backupData = await _decodeUniversalBackup(
      bytes,
      onProgress: (progress, status) async {
        await report(progress, status);
      },
    );

    await report(
      0.46,
      'Datos validados. Creando un punto de recuperación...',
    );
    final safetyBackup = await _createUniversalBackup();

    try {
      await _applyUniversalBackup(
        backupData,
        onProgress: (progress, status) async {
          await report(0.50 + progress * 0.48, status);
        },
      );

      await report(0.99, 'Verificando que la restauración haya terminado...');
      await report(1, 'Restauración completada.');

      return RestoreResult(
        backupFilePath: backupFileName,
        fileCount: backupData.fileCount,
        safetyBackupSizeBytes: safetyBackup.bytes.length,
      );
    } catch (restoreError) {
      await report(
        0.50,
        'Ocurrió un error. Recuperando los datos anteriores...',
      );

      try {
        final safetyData = await _decodeUniversalBackup(safetyBackup.bytes);
        await _applyUniversalBackup(safetyData);
      } catch (rollbackError) {
        throw StateError(
          'No se pudo restaurar el backup seleccionado y tampoco fue posible recuperar automáticamente los datos anteriores. Error de restauración: $restoreError. Error de recuperación: $rollbackError',
        );
      }

      throw StateError(
        'No se pudo completar la restauración. Los datos anteriores fueron recuperados automáticamente. Error: $restoreError',
      );
    }
  }

  static Future<_UniversalBackupData> _decodeUniversalBackup(
    Uint8List bytes, {
    Future<void> Function(double progress, String status)? onProgress,
  }) async {
    Future<void> report(double progress, String status) async {
      await onProgress?.call(progress, status);
      await Future<void>.delayed(Duration.zero);
    }

    await report(0.14, 'Leyendo el archivo ZIP...');
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    await report(0.18, 'Archivo ZIP leído. Validando manifest...');

    final manifestEntry = archive.firstWhere(
      (entry) => entry.name == 'manifest.json' && entry.isFile,
      orElse: () => throw StateError(
        'El backup no contiene un manifest.json válido.',
      ),
    );

    final manifest = jsonDecode(utf8.decode(manifestEntry.content));
    if (manifest is! Map ||
        manifest['format'] != _backupFormat ||
        manifest['version'] != _backupFormatVersion) {
      throw StateError(
        'El backup no tiene una versión universal compatible con STELLAR POS.',
      );
    }

    final rawBoxes = manifest['boxes'];
    if (rawBoxes is! List ||
        rawBoxes.length != _backupBoxNames.length ||
        !rawBoxes.every((value) => _backupBoxNames.contains(value))) {
      throw StateError(
        'El backup no contiene el conjunto de cajas de datos esperado por esta versión de STELLAR POS.',
      );
    }

    final schemaVersion = manifest['schemaVersion'];
    if (schemaVersion is! num ||
        schemaVersion.toInt() > StorageSchema.currentVersion) {
      throw StateError(
        'El backup fue creado con una versión de almacenamiento más nueva (${schemaVersion ?? 'desconocida'}) que esta aplicación (${StorageSchema.currentVersion}).',
      );
    }

    final restoredData = <String, Map<dynamic, dynamic>>{};
    var restoredEntries = 0;

    for (var index = 0; index < _backupBoxNames.length; index++) {
      final boxName = _backupBoxNames[index];
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

      await report(
        0.18 + ((index + 1) / _backupBoxNames.length) * 0.28,
        'Validando ${index + 1} de ${_backupBoxNames.length} secciones...',
      );
    }

    return _UniversalBackupData(
      boxes: restoredData,
      fileCount: restoredEntries,
    );
  }

  static Future<void> _applyUniversalBackup(
    _UniversalBackupData backupData, {
    Future<void> Function(double progress, String status)? onProgress,
  }) async {
    Future<void> report(double progress, String status) async {
      await onProgress?.call(progress, status);
      await Future<void>.delayed(Duration.zero);
    }

    const batchSize = 250;

    for (var index = 0; index < _backupBoxNames.length; index++) {
      final boxName = _backupBoxNames[index];
      final box = await LocalStorage.openBox(boxName);

      await report(
        index / _backupBoxNames.length * 0.10,
        'Preparando ${boxName}...',
      );

      await box.clear().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw StateError(
          'La limpieza de la caja $boxName está tardando demasiado. La restauración fue detenida para evitar un bloqueo indefinido.',
        ),
      );

      final entries = backupData.boxes[boxName]!.entries.toList(
        growable: false,
      );

      for (var start = 0; start < entries.length; start += batchSize) {
        final end = (start + batchSize).clamp(0, entries.length).toInt();
        final batch = <dynamic, dynamic>{
          for (final entry in entries.sublist(start, end))
            entry.key: entry.value,
        };

        await box.putAll(batch).timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw StateError(
            'La escritura de la caja $boxName está tardando demasiado. La restauración fue detenida para evitar un bloqueo indefinido.',
          ),
        );

        final fraction = entries.isEmpty ? 1.0 : end / entries.length;
        await report(
          ((index + fraction) / _backupBoxNames.length) * 0.90,
          'Restaurando ${boxName}: $end de ${entries.length} registros...',
        );
      }

      if (entries.isEmpty) {
        await report(
          ((index + 1) / _backupBoxNames.length) * 0.90,
          'Restaurando ${boxName}: sin registros.',
        );
      }
    }

    await LocalStorage.flush();
    await StorageSchema.initialize();
  }

  static dynamic _jsonSafeValue(dynamic value) {
    if (value == null || value is String || value is bool || value is num) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _jsonSafeValue(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_jsonSafeValue).toList(growable: false);
    }

    throw StateError(
      'Se encontró un tipo de dato no compatible con el formato universal de backup: ${value.runtimeType}.',
    );
  }

  static String _platformName() {
    if (kIsWeb) return 'web';

    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';

    return 'unknown';
  }

  static Future<RestoreResult> _restoreLegacyDesktopBackup({
    required BackupFileSelection backupFile,
    void Function(double progress, String status)? onProgress,
  }) async {
    final backupFilePath = backupFile.path;
    if (backupFilePath == null || backupFilePath.isEmpty) {
      throw StateError(
        'No se encontró la ruta del backup antiguo seleccionado.',
      );
    }

    final backupFileOnDisk = File(backupFilePath);
    if (!await backupFileOnDisk.exists()) {
      throw StateError(
        'No se encontró el archivo de backup antiguo seleccionado.',
      );
    }
    if (!backupFilePath.toLowerCase().endsWith('.zip')) {
      throw StateError(
        'El archivo seleccionado no es un backup ZIP válido.',
      );
    }

    Future<void> report(double progress, String status) async {
      onProgress?.call(progress, status);
      await Future<void>.delayed(Duration.zero);
    }

    await report(
      0.02,
      'Backup antiguo detectado. Preparando restauración compatible con escritorio...',
    );

    final databaseDirectory = Directory(
      await LocalStorage.databaseDirectoryPath(),
    );
    final safetyDirectory = await Directory.systemTemp.createTemp(
      'stellar_pos_legacy_safety_',
    );
    final restoreDirectory = await Directory.systemTemp.createTemp(
      'stellar_pos_legacy_restore_',
    );

    BackupResult? safetyBackup;
    var databaseClosed = false;

    try {
      safetyBackup = await _createLegacyHiveBackup(
        destinationDirectory: safetyDirectory.path,
      );
      await report(
        0.15,
        'Punto de recuperación creado. Validando backup antiguo...',
      );

      final restoredCount = await _extractHiveFiles(
        backupFilePath,
        restoreDirectory.path,
      );
      if (restoredCount <= 0) {
        throw StateError(
          'El backup antiguo no contiene archivos .hive válidos.',
        );
      }

      await report(0.45, 'Backup antiguo validado. Aplicando los datos...');

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
            'stellar_pos_legacy_rollback_',
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
            'No se pudo restaurar el backup antiguo y tampoco fue posible recuperar automáticamente la base anterior. Error de restauración: $restoreError. Error de recuperación: $rollbackError',
          );
        }

        rethrow;
      }

      await report(1, 'Restauración del backup antiguo completada.');
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

  static Future<BackupResult> _createLegacyHiveBackup({
    required String destinationDirectory,
  }) async {
    await LocalStorage.flush();

    final sourceDirectory = Directory(
      await LocalStorage.databaseDirectoryPath(),
    );
    if (!await sourceDirectory.exists()) {
      throw StateError(
        'No se encontró el almacenamiento local de STELLAR POS.',
      );
    }

    final hiveFiles = sourceDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.hive'))
        .toList(growable: false);

    if (hiveFiles.isEmpty) {
      throw StateError(
        'No se encontraron archivos de base de datos para crear el punto de recuperación.',
      );
    }

    final destination = Directory(destinationDirectory);
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    final zipFile = await _nextBackupFile(
      destination,
      prefix: 'stellar_pos_legacy_safety_',
    );

    final hiveFilePaths = hiveFiles
        .map((file) => file.path)
        .toList(growable: false);
    final zipFilePath = zipFile.path;

    final result = await Isolate.run<Map<String, dynamic>>(() async {
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);

      for (final filePath in hiveFilePaths) {
        final file = File(filePath);
        await encoder.addFile(
          file,
          file.uri.pathSegments.last,
        );
      }

      await encoder.close();

      return <String, dynamic>{
        'filePath': zipFilePath,
        'fileCount': hiveFilePaths.length,
        'sizeBytes': await File(zipFilePath).length(),
      };
    }, debugName: 'stellar-pos-legacy-safety-backup');

    return BackupResult(
      filePath: result['filePath'] as String,
      fileCount: result['fileCount'] as int,
      sizeBytes: result['sizeBytes'] as int,
    );
  }

  static bool _containsAsciiSequence(Uint8List data, String value) {
    final needle = utf8.encode(value);
    if (needle.isEmpty || needle.length > data.length) return false;

    for (var index = 0; index <= data.length - needle.length; index++) {
      var matches = true;
      for (var offset = 0; offset < needle.length; offset++) {
        if (data[index + offset] != needle[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
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

  static Future<File> _nextBackupFile(
    Directory destination, {
    String prefix = 'stellar_pos_backup_',
  }) async {
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';

    var file = File(
      '${destination.path}/$prefix$stamp.zip',
    );
    var suffix = 1;
    while (await file.exists()) {
      file = File(
        '${destination.path}/$prefix${stamp}_$suffix.zip',
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
              'El backup antiguo contiene una entrada no permitida. Solo se aceptan archivos .hive.',
            );
          }

          final name = entry.name;
          final safeName = RegExp(
            r'^[^/\\\\]+\\\\.hive$',
            caseSensitive: false,
          );
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
    }, debugName: 'stellar-pos-restore-legacy');
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
