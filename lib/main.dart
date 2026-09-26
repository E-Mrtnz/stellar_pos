import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:stellar_pos/app.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';
import 'package:stellar_pos/core/data/storage/storage_schema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.initialize();
  final hiveDirectory = await getApplicationDocumentsDirectory();
  debugPrint('HIVE CE DATABASE PATH: ${hiveDirectory.path}');
  await StorageSchema.initialize();

  runApp(
    const AppProviders(
      child: StellarPosApp(),
    ),
  );
}
