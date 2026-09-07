import 'package:flutter/material.dart';

import 'package:stellar_pos/presentation/sales/sales_layout.dart';

/// The old electronic-balance route is now used by the navigation slot that
/// represents the sales history. Electronic-balance management remains
/// available from the Punto de venta flow.
class ElectronicBalanceLayout extends StatelessWidget {
  const ElectronicBalanceLayout({super.key});

  @override
  Widget build(BuildContext context) => const SalesLayout();
}
