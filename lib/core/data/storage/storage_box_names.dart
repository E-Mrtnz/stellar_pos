/// Stable Hive box names used by the local persistence layer.
///
/// Keep these names stable: changing one points the application at a new
/// on-disk box and can make existing data appear to be missing.
abstract final class StorageBoxNames {
  static const products = 'products';
  static const clients = 'clients';
  static const providers = 'providers';
  static const sales = 'sales';
  static const purchases = 'purchases';
  static const debts = 'debts';
  static const debtMovements = 'debt_movements';
  static const electronicBalances = 'electronic_balances';
  static const electronicBalanceTransactions = 'electronic_balance_transactions';
}
