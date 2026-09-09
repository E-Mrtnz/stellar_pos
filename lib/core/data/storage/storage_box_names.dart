/// Stable Hive box names used by the local persistence layer.
///
/// Keeping names centralized prevents accidental changes to the on-disk
/// schema when features are refactored.
abstract final class StorageBoxNames {
  static const products = 'products';
  static const clients = 'clients';
  static const providers = 'providers';
  static const sales = 'sales';
  static const purchases = 'purchases';
  static const debts = 'debts';
  static const electronicBalances = 'electronic_balances';
}
