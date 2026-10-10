import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stellar_pos/app.dart';
import 'package:stellar_pos/core/app/app_providers.dart';
import 'package:stellar_pos/core/cloud_firebase.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';
import 'package:stellar_pos/core/data/storage/storage_schema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local storage is the only required startup dependency.
  await LocalStorage.initialize();
  await StorageSchema.initialize();

  runApp(const AppProviders(child: StellarPosApp()));

  // Firebase is optional: initialize only after the UI is running and never
  // block local sales or inventory workflows on the result.
  unawaited(CloudFirebase.initialize());
}
