import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

export 'debt_statement_file_writer_io.dart'
    if (dart.library.html) 'debt_statement_file_writer_web.dart';

Future<XFile> createDebtStatementShareFile(
  Uint8List bytes,
  String fileName,
);

Future<void> cleanupDebtStatementShareFiles(List<XFile> files);
