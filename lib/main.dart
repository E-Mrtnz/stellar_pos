import 'package:flutter/material.dart';

import 'package:stellar_pos/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const AppProviders(
      child: StellarPosApp(),
    ),
  );
}
