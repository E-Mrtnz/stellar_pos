/// Centralized cloud collection names and path construction.
///
/// The cloud database is partitioned by store so multiple devices can share
/// one source of truth without mixing data from different stores.
abstract final class CloudCollection {
  static const products = 'products';
  static const sales = 'sales';
  static const purchases = 'purchases';
  static const clients = 'clients';
  static const distributors = 'distributors';
  static const debts = 'debts';
  static const debtMovements = 'debt_movements';
  static const inventoryMovements = 'inventory_movements';
  static const settings = 'settings';
  static const clientGroups = 'client_groups';
  static const providerRoutes = 'provider_routes';
  static const providerCatalog = 'provider_catalog';
  static const electronicBalanceAccounts = 'electronic_balance_accounts';
  static const electronicBalanceTransactions =
      'electronic_balance_transactions';

  /// Top-level store metadata documents.
  static const stores = 'stores';

  /// Top-level invitation-code lookup documents.
  static const storeInvites = 'store_invites';

  /// Membership subcollection under each store.
  static const members = 'members';

  static String store(String storeId) => 'stores/${storeId.trim()}';

  static String collection({
    required String storeId,
    required String collection,
  }) =>
      '${store(storeId)}/$collection';
}
