import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/constants/app_constants.dart';
import 'package:stellar_pos/core/providers/general_settings_provider.dart';
import 'package:stellar_pos/presentation/Inventory/widgets/create_brand_dialog.dart';
import 'inventory_layout_legacy.dart' as legacy;

class InventoryLayout extends StatelessWidget {
  const InventoryLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GeneralSettingsProvider(),
      child: Stack(
        children: [
          const legacy.InventoryLayout(),
          Positioned(
            right: 20,
            bottom: 164,
            child: FloatingActionButton(
              heroTag: 'fab_brands',
              tooltip: 'Administrar marcas',
              elevation: AppDimensions.inventoryFabElevation,
              shape: const CircleBorder(),
              backgroundColor: AppColors.primary,
              onPressed: () => CreateBrandDialog.show(context),
              child: const Icon(
                Icons.sell_outlined,
                color: Colors.white,
                size: AppSizes.iconLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
