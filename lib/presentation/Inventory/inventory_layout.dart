import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/general_settings_provider.dart';
import 'inventory_layout_legacy.dart' as legacy;

class InventoryLayout extends StatelessWidget {
  const InventoryLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GeneralSettingsProvider(),
      child: Consumer<GeneralSettingsProvider>(
        builder: (context, settings, _) {
          return Stack(
            children: [
              const legacy.InventoryLayout(),
              if (!settings.showInventoryImport)
                _hideAction(const Offset(0, 0), width: 150, right: 185),
              if (!settings.showInventoryExport)
                _hideAction(const Offset(0, 0), width: 165, right: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _hideAction(Offset offset, {required double width, required double right}) {
    return Positioned(
      top: 62,
      right: right,
      width: width,
      height: 46,
      child: IgnorePointer(
        child: Container(color: AppColors.background),
      ),
    );
  }
}
