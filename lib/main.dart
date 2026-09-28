import 'package:flutter/material.dart';
import 'package:stellar_pos/app.dart';
import 'package:stellar_pos/core/cloud/cloud_firebase.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';
import 'package:stellar_pos/core/data/storage/storage_schema.dart';
import 'package:stellar_pos/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.initialize();
  await StorageSchema.initialize();
  await CloudFirebase.initialize(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const AppProviders(
      child: StellarPosApp(),
    ),
  );
}
