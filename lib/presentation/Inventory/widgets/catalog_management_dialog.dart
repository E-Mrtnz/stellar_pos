import 'package:flutter/material.dart';

import 'package:stellar_pos/presentation/widgets/catalog_value_management_dialog.dart';

class CatalogManagementDialog {
  const CatalogManagementDialog._();

  static Future<void> show(
    BuildContext context, {
    required bool isDepartment,
  }) {
    return CatalogValueManagementDialog.show(
      context,
      type: isDepartment
          ? CatalogValueType.distributor
          : CatalogValueType.category,
    );
  }
}
