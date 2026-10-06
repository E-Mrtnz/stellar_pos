import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<XFile> createDebtStatementShareFile(
  Uint8List bytes,
  String fileName,
) async {
  final directory = await getTemporaryDirectory();
  final folder = Directory(
    directory.path + '/stellar_pos/debt_statements',
  );
  await folder.create(recursive: true);

  final file = File(folder.path + '/' + fileName);
  await file.writeAsBytes(bytes, flush: true);

  return XFile(
    file.path,
    mimeType: 'image/png',
    name: fileName,
  );
}

Future<void> cleanupDebtStatementShareFiles(List<XFile> files) async {
  for (final file in files) {
    final path = file.path;
    if (path.isEmpty) {
      continue;
    }

    try {
      final localFile = File(path);
      if (await localFile.exists()) {
        await localFile.delete();
      }
    } catch (_) {
      // Temporary-file cleanup must never make a completed share look like a failure.
    }
  }
}
