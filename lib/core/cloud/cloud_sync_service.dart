import 'package:stellar_pos/core/cloud/cloud_collection.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_engine.dart';
import 'package:stellar_pos/core/data/repositories/client_group_repository.dart';
import 'package:stellar_pos/core/data/repositories/client_repository.dart';
import 'package:stellar_pos/core/data/repositories/debt_movement_repository.dart';
import 'package:stellar_pos/core/data/repositories/electronic_balance_account_repository.dart';
import 'package:stellar_pos/core/data/repositories/electronic_balance_transaction_repository.dart';
import 'package:stellar_pos/core/data/repositories/product_repository.dart';
import 'package:stellar_pos/core/data/repositories/provider_catalog_repository.dart';
import 'package:stellar_pos/core/data/repositories/provider_route_repository.dart';
import 'package:stellar_pos/core/data/repositories/purchase_repository.dart';
import 'package:stellar_pos/core/data/repositories/sale_repository.dart';

/// Coordinates an explicit synchronization pass across all cloud-aware
/// repositories.
///
/// Repositories remain responsible for persistence details. This service only
/// provides an application-level entry point for a future "Sync now" action,
/// startup reconciliation, or background synchronization trigger.
class CloudSyncService {
  final ProductRepository products;
  final ClientRepository clients;
  final PurchaseRepository purchases;
  final SaleRepository sales;
  final DebtMovementRepository debtMovements;
  final ClientGroupRepository clientGroups;
  final ElectronicBalanceAccountRepository electronicBalanceAccounts;
  final ElectronicBalanceTransactionRepository electronicBalanceTransactions;
  final ProviderRouteRepository providerRoutes;
  final ProviderCatalogRepository providerCatalog;

  CloudSyncService({
    ProductRepository? products,
    ClientRepository? clients,
    PurchaseRepository? purchases,
    SaleRepository? sales,
    DebtMovementRepository? debtMovements,
    ClientGroupRepository? clientGroups,
    ElectronicBalanceAccountRepository? electronicBalanceAccounts,
    ElectronicBalanceTransactionRepository? electronicBalanceTransactions,
    ProviderRouteRepository? providerRoutes,
    ProviderCatalogRepository? providerCatalog,
  })  : products = products ?? ProductRepository(),
        clients = clients ?? ClientRepository(),
        purchases = purchases ?? PurchaseRepository(),
        sales = sales ?? SaleRepository(),
        debtMovements = debtMovements ?? DebtMovementRepository(),
        clientGroups = clientGroups ?? ClientGroupRepository(),
        electronicBalanceAccounts =
            electronicBalanceAccounts ?? ElectronicBalanceAccountRepository(),
        electronicBalanceTransactions = electronicBalanceTransactions ??
            ElectronicBalanceTransactionRepository(),
        providerRoutes = providerRoutes ?? ProviderRouteRepository(),
        providerCatalog = providerCatalog ?? ProviderCatalogRepository();

  /// Synchronizes one cloud-aware collection.
  ///
  /// Realtime listeners use this targeted entry point so a change in one
  /// collection does not force every repository to perform a full pull.
  Future<CloudSyncResult?> syncCollection(String collection) async {
    switch (collection) {
      case CloudCollection.products:
        return products.sync();
      case CloudCollection.sales:
        return sales.sync();
      case CloudCollection.purchases:
        return purchases.sync();
      case CloudCollection.clients:
        return clients.sync();
      case CloudCollection.debtMovements:
        return debtMovements.sync();
      case CloudCollection.clientGroups:
        return clientGroups.sync();
      case CloudCollection.providerRoutes:
        return providerRoutes.sync();
      case CloudCollection.providerCatalog:
        return providerCatalog.sync();
      case CloudCollection.electronicBalanceAccounts:
        return electronicBalanceAccounts.sync();
      case CloudCollection.electronicBalanceTransactions:
        return electronicBalanceTransactions.sync();
      default:
        throw ArgumentError.value(
          collection,
          'collection',
          'La colección no tiene un repositorio de sincronización.',
        );
    }
  }

  /// Runs synchronization for every cloud-aware repository.
  ///
  /// Each repository is best-effort and keeps local operation available when
  /// Firebase is unavailable. Futures are intentionally started together so
  /// independent collections can synchronize concurrently; the shared
  /// [CloudSyncCoordinator] still prevents duplicate work per collection.
  Future<CloudSyncResult> syncAll() async {
    final results = await Future.wait<CloudSyncResult?>([
      products.sync(),
      clients.sync(),
      purchases.sync(),
      sales.sync(),
      debtMovements.sync(),
      clientGroups.sync(),
      electronicBalanceAccounts.sync(),
      electronicBalanceTransactions.sync(),
      providerRoutes.sync(),
      providerCatalog.sync(),
    ]);

    var total = const CloudSyncResult();
    for (final result in results) {
      if (result != null) {
        total = total + result;
      }
    }
    return total;
  }
}
