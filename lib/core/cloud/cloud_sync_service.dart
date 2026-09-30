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

  /// Forces every cloud-aware repository to upload its complete local
  /// dataset, regardless of checkpoints or previous sync state.
  Future<CloudSyncResult> forceUploadAll({
    CloudSyncProgressCallback? onProgress,
  }) async {
    final operations = <({
      String collection,
      Future<CloudSyncResult?> Function(CloudSyncProgressCallback) run,
    })>[
      (
        collection: CloudCollection.products,
        run: (onProgress) => products.forceUpload(onProgress: onProgress),
      ),
      (
        collection: CloudCollection.clients,
        run: (onProgress) => clients.forceUpload(onProgress: onProgress),
      ),
      (
        collection: CloudCollection.purchases,
        run: (onProgress) => purchases.forceUpload(onProgress: onProgress),
      ),
      (
        collection: CloudCollection.sales,
        run: (onProgress) => sales.forceUpload(onProgress: onProgress),
      ),
      (
        collection: CloudCollection.debtMovements,
        run: (onProgress) => debtMovements.forceUpload(onProgress: onProgress),
      ),
      (
        collection: CloudCollection.clientGroups,
        run: (onProgress) => clientGroups.forceUpload(onProgress: onProgress),
      ),
      (
        collection: CloudCollection.electronicBalanceAccounts,
        run: (onProgress) => electronicBalanceAccounts.forceUpload(onProgress: onProgress),
      ),
      (
        collection: CloudCollection.electronicBalanceTransactions,
        run: (onProgress) => electronicBalanceTransactions.forceUpload(onProgress: onProgress),
      ),
      (
        collection: CloudCollection.providerRoutes,
        run: (onProgress) => providerRoutes.forceUpload(onProgress: onProgress),
      ),
      (
        collection: CloudCollection.providerCatalog,
        run: (onProgress) => providerCatalog.forceUpload(onProgress: onProgress),
      ),
    ];

    var total = const CloudSyncResult();

    // Manual upload is deliberately sequential by collection. Each entity is
    // uploaded concurrently inside its own repository, while collections are
    // isolated so a large product catalog cannot make ten repositories fight
    // over the same local storage/connection resources.
    for (var index = 0; index < operations.length; index++) {
      final operation = operations[index];
      final result = await operation.run((progress) {
        onProgress?.call(
          CloudSyncProgress(
            collection: progress.collection,
            phase: progress.phase,
            processed: progress.processed,
            total: progress.total,
            uploaded: progress.uploaded,
            failed: progress.failed,
            errors: progress.errors,
            collectionIndex: index,
            collectionCount: operations.length,
          ),
        );
      });

      if (result != null) {
        total = total + result;
      }
    }

    return total;
  }

  /// Runs synchronization for every cloud-aware repository.
  ///
  /// Each repository is best-effort and keeps local operation available when
  /// Firebase is unavailable. Futures are intentionally started together so
  /// independent collections can synchronize concurrently; the shared
  /// [CloudSyncCoordinator] still prevents duplicate work per collection.
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
