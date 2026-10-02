import 'package:flutter/material.dart';

import 'package:stellar_pos/presentation/widgets/catalog_value_management_dialog.dart';

class CreateClientGroupDialog {
  const CreateClientGroupDialog._();

  static Future<void> show(BuildContext context) {
    return CatalogValueManagementDialog.show(
      context,
      type: CatalogValueType.clientGroup,
    );
  }
}
