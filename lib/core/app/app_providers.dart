import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/data/repositories/client_repository.dart';
import 'package:stellar_pos/core/data/repositories/debt_movement_repository.dart';
import 'package:stellar_pos/core/data/repositories/electronic_balance_account_repository.dart';
import 'package:stellar_pos/core/data/repositories/electronic_balance_transaction_repository.dart';
import 'package:stellar_pos/core/data/repositories/product_repository.dart';
import 'package:stellar_pos/core/data/repositories/provider_catalog_repository.dart';
import 'package:stellar_pos/core/data/repositories/provider_route_repository.dart';
import 'package:stellar_pos/core/data/repositories/purchase_repository.dart';
import 'package:stellar_pos/core/data/repositories/sale_repository.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';
import 'package:stellar_pos/core/providers/printer_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';
import 'package:stellar_pos/features/debts/debts.dart';
import 'package:stellar_pos/features/purchases/purchases.dart';
import 'package:stellar_pos/features/sales/sales.dart';

class AppProviders extends StatelessWidget {
  final Widget child;
  const AppProviders({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CatalogProvider(
            clientRepository: ClientRepository(),
            productRepository: ProductRepository(),
            routeRepository: ProviderRouteRepository(),
            catalogRepository: ProviderCatalogRepository(),
          )
            ..load()
            ..loadClients(),
        ),
        ChangeNotifierProxyProvider<CatalogProvider, ProductProvider>(
          create: (context) => ProductProvider(
            catalogRegistrar: context.read<CatalogProvider>(),
            repository: ProductRepository(),
          )..load(),
          update: (_, catalog, products) => products ?? ProductProvider(
            catalogRegistrar: catalog,
            repository: ProductRepository(),
          )..load(),
        ),
        ChangeNotifierProxyProvider<CatalogProvider, ProvidersProvider>(
          create: (context) => ProvidersProvider(
            catalogProvider: context.read<CatalogProvider>(),
            routeRepository: ProviderRouteRepository(),
          )..load(),
          update: (_, catalog, providers) {
            if (providers == null) {
              return ProvidersProvider(
                catalogProvider: catalog,
                routeRepository: ProviderRouteRepository(),
              )..load();
            }
            providers.attachCatalog(catalog);
            return providers;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => PurchasesProvider(repository: PurchaseRepository())..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => ElectronicBalanceProvider(
            accountRepository: ElectronicBalanceAccountRepository(),
            transactionRepository: ElectronicBalanceTransactionRepository(),
          )..load(),
        ),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider(
          create: (_) => SalesProvider(repository: SaleRepository())..load(),
        ),
        ChangeNotifierProvider(
          create: (context) => DebtProvider(
            context.read<SalesProvider>(),
            movementRepository: DebtMovementRepository(),
          )..load(),
        ),
      ],
      child: child,
    );
  }
}
