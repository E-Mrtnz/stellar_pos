import 'package:flutter/material.dart';

import 'package:stellar_pos/presentation/Inventory/widgets/client_management_dialog.dart';

/// Backwards-compatible entry point for creating clients.
///
/// The dialog now also exposes the existing clients below the form, so client
/// management follows the same pattern used by categories, brands and
/// distributors without changing the call sites that already use this class.
class CreateClientDialog {
  const CreateClientDialog._();

  static Future<void> show(BuildContext context) {
    return ClientManagementDialog.show(context);
  }
}
