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
  Future<void> syncCollection(String collection) async {
    switch (collection) {
      case 'products':
        await products.sync();
        return;
      case 'sales':
        await sales.sync();
        return;
      case 'purchases':
        await purchases.sync();
        return;
      case 'clients':
        await clients.sync();
        return;
      case 'debt_movements':
        await debtMovements.sync();
        return;
      case 'client_groups':
        await clientGroups.sync();
        return;
      case 'provider_routes':
        await providerRoutes.sync();
        return;
      case 'provider_catalog':
        await providerCatalog.sync();
        return;
      case 'electronic_balance_accounts':
        await electronicBalanceAccounts.sync();
        return;
      case 'electronic_balance_transactions':
        await electronicBalanceTransactions.sync();
        return;
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
  Future<void> syncAll() async {
    await Future.wait<void>([
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
  }
}
