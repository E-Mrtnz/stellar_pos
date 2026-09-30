import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/cloud/cloud_auto_sync_service.dart';
import 'package:stellar_pos/core/cloud/cloud_realtime_sync_service.dart';
import 'package:stellar_pos/core/cloud/cloud_realtime_ui_bridge.dart';
import 'package:stellar_pos/core/data/repositories/client_group_repository.dart';
import 'package:stellar_pos/core/providers/cloud_store_provider.dart';
import 'package:stellar_pos/core/providers/cloud_access_provider.dart';
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
import 'package:stellar_pos/core/providers/client_group_provider.dart';
import 'package:stellar_pos/core/providers/date_aware_sales_provider.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';
import 'package:stellar_pos/core/providers/printer_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
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
          create: (_) => CloudStoreProvider()..load(),
        ),
        Provider<CloudAutoSyncService>(
          lazy: false,
          create: (_) => CloudAutoSyncService()..start(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProxyProvider<CloudStoreProvider, CloudRealtimeSyncService>(
          create: (_) => CloudRealtimeSyncService()..start(),
          update: (_, store, realtime) {
            final service = realtime ?? (CloudRealtimeSyncService()..start());
            unawaited(service.setStoreId(store.storeId));
            return service;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => CloudAccessProvider()..load(),
        ),
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
          create: (context) => ElectronicBalanceProvider(
            accountRepository: ElectronicBalanceAccountRepository(),
            transactionRepository: ElectronicBalanceTransactionRepository(),
            purchasesProvider: context.read<PurchasesProvider>(),
          )..load(),
        ),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
        ChangeNotifierProvider<SalesProvider>(
          create: (_) => DateAwareSalesProvider(repository: SaleRepository())..load(),
        ),
        ChangeNotifierProvider(
          create: (context) => DebtProvider(
            context.read<SalesProvider>(),
            movementRepository: DebtMovementRepository(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => ClientGroupProvider()..load(),
        ),
      ],
      child: CloudRealtimeUiBridge(child: child),
    );
  }
}
