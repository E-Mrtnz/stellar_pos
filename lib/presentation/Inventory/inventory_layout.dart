import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stellar_pos/core/providers/general_settings_provider.dart';
import 'inventory_layout_legacy.dart' as legacy;

class InventoryLayout extends StatelessWidget {
  const InventoryLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GeneralSettingsProvider(),
      child: const legacy.InventoryLayout(),
    );
  }
}
