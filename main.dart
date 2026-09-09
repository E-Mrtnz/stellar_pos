import 'package:flutter/material.dart';
import 'package:stellar_pos/app.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.initialize();
  runApp(
    const AppProviders(
      child: StellarPosApp(),
    ),
  );
}
