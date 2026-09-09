import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/data/repositories/electronic_balance_account_repository.dart';
import 'package:stellar_pos/core/data/repositories/electronic_balance_transaction_repository.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/electronic_balance_sale.dart';
import 'package:stellar_pos/core/domain/services/electronic_balance_service.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class ElectronicBalanceProvider extends ChangeNotifier {
  static const validCategories = ElectronicBalanceService.validCategoryOrder;

  final ElectronicBalanceService _service;
  final List<ElectronicBalanceAccount> _accounts = [];
  final List<ElectronicBalanceTransaction> _transactions = [];
  final Repository<ElectronicBalanceAccount>? _accountRepository;
  final Repository<ElectronicBalanceTransaction>? _transactionRepository;
  bool _loaded = false;
  Future<void>? _loadFuture;

  ElectronicBalanceProvider({
    ElectronicBalanceService? service,
    Repository<ElectronicBalanceAccount>? accountRepository,
    Repository<ElectronicBalanceTransaction>? transactionRepository,
  })  : _service = service ?? AppDependencies.electronicBalance,
        _accountRepository = accountRepository ?? ElectronicBalanceAccountRepository(),
        _transactionRepository = transactionRepository ?? ElectronicBalanceTransactionRepository();

  List<ElectronicBalanceAccount> get accounts {
    final result = List<ElectronicBalanceAccount>.from(_accounts)
      ..sort((a, b) => a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()));
    return List.unmodifiable(result);
  }

  List<ElectronicBalanceTransaction> get transactions => List.unmodifiable(_transactions);

  Future<void> load() {
    if (_loaded) return Future.value();
    final existing = _loadFuture;
    if (existing != null) return existing;
    final future = _loadFromRepository();
    _loadFuture = future;
    return future;
  }

  ElectronicBalanceAccount? findAccount(String id) {
    for (final account in _accounts) if (account.id == id) return account;
    return null;
  }

  bool addAccount({required String companyName, required double commissionRate}) {
    final name = companyName.trim();
    if (name.isEmpty || commissionRate < 0 || commissionRate > 100) return false;
    if (_accounts.any((a) => a.companyName.toLowerCase() == name.toLowerCase())) return false;
    final account = ElectronicBalanceAccount(id: IdGenerator.newId(), companyName: name, commissionRate: commissionRate, balance: 0);
    _accounts.add(account);
    notifyListeners();
    _persistAccount(account);
    return true;
  }

  bool updateAccount({required String id, required String companyName, required double commissionRate}) {
    final index = _accounts.indexWhere((a) => a.id == id);
    final name = companyName.trim();
    if (index < 0 || name.isEmpty || commissionRate < 0 || commissionRate > 100) return false;
    if (_accounts.asMap().entries.any((e) => e.key != index && e.value.companyName.toLowerCase() == name.toLowerCase())) return false;
    final account = _accounts[index].copyWith(companyName: name, commissionRate: commissionRate);
    _accounts[index] = account;
    notifyListeners();
    _persistAccount(account);
    return true;
  }

  bool removeAccount(String id) {
    if (_transactions.any((t) => t.accountId == id)) return false;
    final before = _accounts.length;
    _accounts.removeWhere((a) => a.id == id);
    if (_accounts.length == before) return false;
    notifyListeners();
    _persistDeleteAccount(id);
    return true;
  }

  bool setSaleOptions({required String accountId, required List<ElectronicBalanceSaleOption> options}) {
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index < 0) return false;
    final normalized = <ElectronicBalanceSaleOption>[];
    final seen = <String>{};
    for (final option in options) {
      final category = option.category.trim();
      if (option.amount <= 0 || !_service.isValidCategory(category)) continue;
      if (seen.add('$category|${option.amount.toStringAsFixed(4)}')) normalized.add(ElectronicBalanceSaleOption(category: category, amount: option.amount));
    }
    normalized.sort((a, b) {
      final byCategory = validCategories.indexOf(a.category).compareTo(validCategories.indexOf(b.category));
      return byCategory == 0 ? a.amount.compareTo(b.amount) : byCategory;
    });
    final account = _accounts[index].copyWith(saleOptions: normalized);
    _accounts[index] = account;
    notifyListeners();
    _persistAccount(account);
    return true;
  }

  bool registerPurchase({required String accountId, required double amount}) {
    if (amount <= 0) return false;
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index < 0) return false;
    final account = _accounts[index];
    final transaction = ElectronicBalanceTransaction(id: IdGenerator.newId(), accountId: accountId, type: ElectronicBalanceTransactionType.purchase, amount: amount, providerCost: _service.providerCost(amount: amount, commissionRate: account.commissionRate), profit: _service.profit(amount: amount, commissionRate: account.commissionRate), category: 'Compra de saldo', description: 'Recarga de saldo', createdAt: DateTime.now());
    final updatedAccount = account.copyWith(balance: account.balance + amount);
    _accounts[index] = updatedAccount;
    _transactions.add(transaction);
    notifyListeners();
    _persistAccount(updatedAccount);
    _persistTransaction(transaction);
    return true;
  }

  bool registerSale({required String accountId, required double amount, required String category, String description = ''}) => registerSales(accountId: accountId, sales: [ElectronicBalanceSale(amount: amount, quantity: 1, category: category, description: description)]);

  bool registerSales({required String accountId, required List<ElectronicBalanceSale> sales, String? saleId}) {
    if (sales.isEmpty) return false;
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index < 0) return false;
    final account = _accounts[index];
    final now = DateTime.now();
    final pending = <ElectronicBalanceTransaction>[];
    var totalAmount = 0.0;
    for (final sale in sales) {
      final category = sale.category.trim();
      if (sale.amount <= 0 || sale.quantity <= 0 || !_service.isValidCategory(category)) return false;
      final amount = sale.amount * sale.quantity;
      pending.add(ElectronicBalanceTransaction(id: IdGenerator.newId(), accountId: accountId, type: ElectronicBalanceTransactionType.sale, amount: amount, providerCost: _service.providerCost(amount: amount, commissionRate: account.commissionRate), profit: _service.profit(amount: amount, commissionRate: account.commissionRate), category: category, description: sale.description.trim(), createdAt: now, saleId: saleId));
      totalAmount += amount;
    }
    final updatedAccount = account.copyWith(balance: account.balance - totalAmount);
    _accounts[index] = updatedAccount;
    _transactions.addAll(pending);
    notifyListeners();
    _persistAccount(updatedAccount);
    for (final transaction in pending) _persistTransaction(transaction);
    return true;
  }

  bool reverseSale(String saleId) {
    final matching = _transactions.where((t) => t.saleId == saleId && t.type == ElectronicBalanceTransactionType.sale).toList();
    if (matching.isEmpty) return false;
    final byAccount = <String, double>{};
    for (final transaction in matching) byAccount[transaction.accountId] = (byAccount[transaction.accountId] ?? 0) + transaction.amount;
    for (final entry in byAccount.entries) {
      final index = _accounts.indexWhere((a) => a.id == entry.key);
      if (index < 0) return false;
      final account = _accounts[index].copyWith(balance: _accounts[index].balance + entry.value);
      _accounts[index] = account;
      _persistAccount(account);
    }
    _transactions.removeWhere((t) => t.saleId == saleId && t.type == ElectronicBalanceTransactionType.sale);
    for (final transaction in matching) _persistDeleteTransaction(transaction.id);
    notifyListeners();
    return true;
  }

  double totalPurchased(String id) => _transactions.where((t) => t.accountId == id && t.type == ElectronicBalanceTransactionType.purchase).fold(0, (sum, t) => sum + t.amount);
  double totalSold(String id) => _transactions.where((t) => t.accountId == id && t.type == ElectronicBalanceTransactionType.sale).fold(0, (sum, t) => sum + t.amount);
  double totalProfit(String id) => _transactions.where((t) => t.accountId == id && t.type == ElectronicBalanceTransactionType.sale).fold(0, (sum, t) => sum + t.profit);
  List<ElectronicBalanceTransaction> transactionsFor(String id) => _transactions.where((t) => t.accountId == id).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> _loadFromRepository() async {
    final accounts = await _accountRepository?.getAll() ?? const <ElectronicBalanceAccount>[];
    final transactions = await _transactionRepository?.getAll() ?? const <ElectronicBalanceTransaction>[];
    _accounts..clear()..addAll(accounts);
    _transactions..clear()..addAll(transactions);
    _loaded = true;
    if (_accounts.isNotEmpty || _transactions.isNotEmpty) notifyListeners();
  }

  void _persistAccount(ElectronicBalanceAccount account) { _accountRepository?.save(account).catchError((_) {}); }
  void _persistTransaction(ElectronicBalanceTransaction transaction) { _transactionRepository?.save(transaction).catchError((_) {}); }
  void _persistDeleteAccount(String id) { _accountRepository?.delete(id).catchError((_) {}); }
  void _persistDeleteTransaction(String id) { _transactionRepository?.delete(id).catchError((_) {}); }
}
