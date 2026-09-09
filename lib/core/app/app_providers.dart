import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/data/repositories/product_repository.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/printer_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/features/catalog/catalog.dart';
import 'package:stellar_pos/features/debts/debts.dart';
import 'package:stellar_pos/features/electronic_balance/electronic_balance.dart';
import 'package:stellar_pos/features/purchases/purchases.dart';
import 'package:stellar_pos/features/sales/sales.dart';

/// Composition root for presentation/application state dependencies.
class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProxyProvider<CatalogProvider, ProductProvider>(
          create: (context) => ProductProvider(
            catalogRegistrar: context.read<CatalogProvider>(),
            repository: ProductRepository(),
          )..load(),
          update: (_, catalog, products) =>
              products ??
              ProductProvider(
                catalogRegistrar: catalog,
                repository: ProductRepository(),
              )..load(),
        ),
        ChangeNotifierProvider(create: (_) => ProvidersProvider()),
        ChangeNotifierProvider(create: (_) => PurchasesProvider()),
        ChangeNotifierProvider(create: (_) => ElectronicBalanceProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(
          create: (context) => DebtProvider(context.read<SalesProvider>()),
        ),
      ],
      child: child,
    );
  }
}
