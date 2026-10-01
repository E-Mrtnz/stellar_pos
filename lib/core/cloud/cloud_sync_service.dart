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

/// Coordinates the automatic synchronization pass across all cloud-aware
/// repositories.
///
/// Repositories remain responsible for local persistence. This service only
/// orchestrates the order in which each collection reconciles with Firestore.
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

  /// Applies only the documents reported by a realtime Firestore snapshot.
  ///
  /// This intentionally avoids a collection-wide read. The realtime listener
  /// already gives us the changed documents, so only those records are written
  /// into Hive.
  Future<int> applyRemoteChanges(
    String collection, {
    Iterable<Map<String, dynamic>> documents =
        const <Map<String, dynamic>>[],
    Iterable<String> deletedIds = const <String>[],
  }) async {
    var applied = 0;

    for (final document in documents) {
      final changed = switch (collection) {
        CloudCollection.products => await products.applyRemoteData(document),
        CloudCollection.sales => await sales.applyRemoteData(document),
        CloudCollection.purchases =>
          await purchases.applyRemoteData(document),
        CloudCollection.clients => await clients.applyRemoteData(document),
        CloudCollection.debtMovements =>
          await debtMovements.applyRemoteData(document),
        CloudCollection.clientGroups =>
          await clientGroups.applyRemoteData(document),
        CloudCollection.providerRoutes =>
          await providerRoutes.applyRemoteData(document),
        CloudCollection.providerCatalog =>
          await providerCatalog.applyRemoteData(document),
        CloudCollection.electronicBalanceAccounts =>
          await electronicBalanceAccounts.applyRemoteData(document),
        CloudCollection.electronicBalanceTransactions =>
          await electronicBalanceTransactions.applyRemoteData(document),
        _ => false,
      };
      if (changed) applied++;
    }

    for (final id in deletedIds) {
      final changed = switch (collection) {
        CloudCollection.products => await products.applyRemoteDelete(id),
        CloudCollection.sales => await sales.applyRemoteDelete(id),
        CloudCollection.purchases => await purchases.applyRemoteDelete(id),
        CloudCollection.clients => await clients.applyRemoteDelete(id),
        CloudCollection.debtMovements =>
          await debtMovements.applyRemoteDelete(id),
        CloudCollection.clientGroups =>
          await clientGroups.applyRemoteDelete(id),
        CloudCollection.providerRoutes =>
          await providerRoutes.applyRemoteDelete(id),
        CloudCollection.providerCatalog =>
          await providerCatalog.applyRemoteDelete(id),
        CloudCollection.electronicBalanceAccounts =>
          await electronicBalanceAccounts.applyRemoteDelete(id),
        CloudCollection.electronicBalanceTransactions =>
          await electronicBalanceTransactions.applyRemoteDelete(id),
        _ => false,
      };
      if (changed) applied++;
    }

    return applied;
  }

  /// Restores all collections from Firestore when a device joins a
  /// store. Pre-existing local data on that device is not uploaded.
  Future<CloudSyncResult> restoreFromCloud() async {
    final operations = <Future<CloudSyncResult?> Function()>[
      products.restoreFromCloud,
      clients.restoreFromCloud,
      purchases.restoreFromCloud,
      sales.restoreFromCloud,
      debtMovements.restoreFromCloud,
      clientGroups.restoreFromCloud,
      electronicBalanceAccounts.restoreFromCloud,
      electronicBalanceTransactions.restoreFromCloud,
      providerRoutes.restoreFromCloud,
      providerCatalog.restoreFromCloud,
    ];

    var total = const CloudSyncResult();
    for (final operation in operations) {
      final result = await operation();
      if (result != null) {
        total = total + result;
      }
    }
    return total;
  }

  /// Runs synchronization for every cloud-aware repository.
  ///
  /// Each repository is best-effort. Collections are reconciled sequentially so
  /// one collection can fail without preventing the remaining collections from
  /// attempting their own automatic synchronization.
  Future<CloudSyncResult> syncAll() async {
    final operations = <Future<CloudSyncResult?> Function()>[
      products.sync,
      clients.sync,
      purchases.sync,
      sales.sync,
      debtMovements.sync,
      clientGroups.sync,
      electronicBalanceAccounts.sync,
      electronicBalanceTransactions.sync,
      providerRoutes.sync,
      providerCatalog.sync,
    ];

    var total = const CloudSyncResult();

    // Repositories share the same durable Hive sync queue. Running the first
    // reconciliation for every collection concurrently made large local
    // migrations compete for that queue and could leave the app apparently
    // idle for a long time. Keep the reconciliation deterministic; each
    // collection still performs its own network work asynchronously.
    for (final operation in operations) {
      final result = await operation();
      if (result != null) {
        total = total + result;
      }
    }

    return total;
  }

}
