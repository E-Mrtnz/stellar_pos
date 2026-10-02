/// Names of the local Hive boxes used by STELLAR_POS.
///
/// Keep these names stable. Changing a name would point the application at a
/// different on-disk box and could make previously stored data appear to be missing.
class StorageBoxes {
  const StorageBoxes._();

  static const products = 'products';
  static const clients = 'clients';
  static const providerRoutes = 'provider_routes';
  static const providerCatalog = 'provider_catalog';
  static const sales = 'sales';
  static const purchases = 'purchases';
  static const debtAccounts = 'debt_accounts';
  static const debtMovements = 'debt_movements';
  static const clientGroups = 'client_groups';
  static const electronicBalanceAccounts = 'electronic_balance_accounts';
  static const electronicBalanceTransactions = 'electronic_balance_transactions';
  static const storageMetadata = '__storage_metadata';
}
