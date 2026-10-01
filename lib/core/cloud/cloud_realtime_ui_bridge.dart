import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:stellar_pos/core/cloud/cloud_collection.dart';
import 'package:stellar_pos/core/cloud/cloud_realtime_sync_service.dart';
import 'package:stellar_pos/core/providers/cloud_store_provider.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/providers/client_group_provider.dart';
import 'package:stellar_pos/core/providers/debt_provider.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';
import 'package:stellar_pos/core/providers/purchases_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';

/// Bridges completed cloud synchronization into the existing presentation
/// state without exposing Firestore to widgets or providers.
///
/// Repositories remain the source of truth. Providers simply refresh their
/// in-memory view state after the synchronization engine has updated local
/// persistence.
class CloudRealtimeUiBridge extends StatefulWidget {
  final Widget child;

  const CloudRealtimeUiBridge({
    required this.child,
    super.key,
  });

  @override
  State<CloudRealtimeUiBridge> createState() => _CloudRealtimeUiBridgeState();
}

class _CloudRealtimeUiBridgeState extends State<CloudRealtimeUiBridge> {
  late final CloudRealtimeSyncService _realtime;
  late final CloudStoreProvider _storeProvider;

  @override
  void initState() {
    super.initState();
    _realtime = context.read<CloudRealtimeSyncService>();
    _storeProvider = context.read<CloudStoreProvider>();
    _realtime.addListener(_onRealtimeSync);
    _storeProvider.addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    // Joining a store restores Firestore data directly into Hive. That local
    // restore does not emit a Firestore snapshot, so refresh the in-memory
    // providers when the store identity changes.
    if (!mounted || !_storeProvider.isConfigured) return;
    _refreshAllProviders();
  }

  void _refreshAllProviders() {
    unawaited(context.read<ProductProvider>().refreshFromRepository());
    unawaited(context.read<CatalogProvider>().refreshFromRepository());
    unawaited(context.read<SalesProvider>().refreshFromRepository());
    unawaited(context.read<PurchasesProvider>().refreshFromRepository());
    unawaited(context.read<DebtProvider>().refreshFromRepository());
    unawaited(context.read<ClientGroupProvider>().refreshFromRepository());
    unawaited(context.read<ProvidersProvider>().refreshFromRepository());
    unawaited(context.read<ElectronicBalanceProvider>().refreshFromRepository());
  }

  void _onRealtimeSync() {
    final collection = _realtime.lastSyncedCollection;
    if (collection == null || !mounted) return;

    switch (collection) {
      case CloudCollection.products:
        unawaited(context.read<ProductProvider>().refreshFromRepository());
        unawaited(context.read<CatalogProvider>().refreshFromRepository());
        break;
      case CloudCollection.sales:
        unawaited(context.read<SalesProvider>().refreshFromRepository());
        // Debt accounts are derived from sales, so a remote sale can change
        // the debt view even when no debt movement document changed.
        unawaited(context.read<DebtProvider>().refreshFromRepository());
        break;
      case CloudCollection.purchases:
        unawaited(context.read<PurchasesProvider>().refreshFromRepository());
        break;
      case CloudCollection.clients:
        unawaited(context.read<CatalogProvider>().refreshFromRepository());
        break;
      case CloudCollection.debtMovements:
        unawaited(context.read<DebtProvider>().refreshFromRepository());
        break;
      case CloudCollection.clientGroups:
        unawaited(context.read<ClientGroupProvider>().refreshFromRepository());
        break;
      case CloudCollection.providerRoutes:
        unawaited(context.read<ProvidersProvider>().refreshFromRepository());
        unawaited(context.read<CatalogProvider>().refreshFromRepository());
        break;
      case CloudCollection.providerCatalog:
        unawaited(context.read<CatalogProvider>().refreshFromRepository());
        break;
      case CloudCollection.electronicBalanceAccounts:
      case CloudCollection.electronicBalanceTransactions:
        unawaited(
          context.read<ElectronicBalanceProvider>().refreshFromRepository(),
        );
        break;
    }
  }

  @override
  void dispose() {
    _realtime.removeListener(_onRealtimeSync);
    _storeProvider.removeListener(_onStoreChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
