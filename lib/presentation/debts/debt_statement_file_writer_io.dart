import 'dart:io';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<XFile> createDebtStatementShareFile(
  Uint8List bytes,
  String fileName,
) async {
  // Use Dart's native system temp directory for native platforms. This
  // avoids an extra platform-channel dependency in the critical share path.
  final directory = await Directory.systemTemp.createTemp(
    'stellar_pos_debt_statement_',
  );

  final file = File('${directory.path}/$fileName');
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
      final parent = localFile.parent;

      if (await localFile.exists()) {
        await localFile.delete();
      }

      if (parent.path != Directory.systemTemp.path &&
          await parent.exists()) {
        await parent.delete();
      }
    } catch (_) {
      // Temporary-file cleanup must never make a completed share look like a failure.
    }
  }
}
