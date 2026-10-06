import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<XFile> createDebtStatementShareFile(
  Uint8List bytes,
  String fileName,
) async {
  return XFile.fromData(
    bytes,
    mimeType: 'image/png',
    name: fileName,
  );
}

Future<void> cleanupDebtStatementShareFiles(List<XFile> files) async {
  // share_plus manages the temporary files required by the web fallback.
}
