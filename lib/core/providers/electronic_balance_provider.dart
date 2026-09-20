import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/data/repositories/electronic_balance_account_repository.dart';
import 'package:stellar_pos/core/data/repositories/electronic_balance_transaction_repository.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/electronic_balance_sale.dart';
import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/providers/purchases_provider.dart';
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
  final PurchasesProvider? _purchasesProvider;
  bool _loaded = false;
  Future<void>? _loadFuture;

  ElectronicBalanceProvider({
    ElectronicBalanceService? service,
    Repository<ElectronicBalanceAccount>? accountRepository,
    Repository<ElectronicBalanceTransaction>? transactionRepository,
    PurchasesProvider? purchasesProvider,
  })  : _service = service ?? AppDependencies.electronicBalance,
        _accountRepository = accountRepository ?? ElectronicBalanceAccountRepository(),
        _transactionRepository = transactionRepository ?? ElectronicBalanceTransactionRepository(),
        _purchasesProvider = purchasesProvider;

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
      final commission = option.commissionRate;
      if (option.amount <= 0 || !_service.isValidCategory(category)) continue;
      if (commission != null && (commission < 0 || commission > 100)) continue;
      final isStandard = validCategories.contains(category);
      final normalizedCommission = isStandard ? null : commission;
      if (!isStandard && normalizedCommission == null) continue;
      if (seen.add('$category|${option.amount.toStringAsFixed(4)}')) {
        normalized.add(
          ElectronicBalanceSaleOption(
            category: category,
            amount: option.amount,
            commissionRate: normalizedCommission,
          ),
        );
      }
    }

    final customOrder = <String>[];
    for (final option in normalized) {
      if (!validCategories.contains(option.category) && !customOrder.contains(option.category)) {
        customOrder.add(option.category);
      }
    }
    final categoryRank = <String, int>{
      for (var i = 0; i < validCategories.length; i++) validCategories[i]: i,
    };
    normalized.sort((a, b) {
      final aRank = categoryRank[a.category] ?? (validCategories.length + customOrder.indexOf(a.category));
      final bRank = categoryRank[b.category] ?? (validCategories.length + customOrder.indexOf(b.category));
      final byCategory = aRank.compareTo(bRank);
      return byCategory == 0 ? a.amount.compareTo(b.amount) : byCategory;
    });

    final account = _accounts[index].copyWith(saleOptions: normalized);
    _accounts[index] = account;
    notifyListeners();
    _persistAccount(account);
    return true;
  }

  bool registerPurchase({required String accountId, required double amount, String category = 'Saldo'}) {
    if (amount <= 0) return false;
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index < 0) return false;
    final account = _accounts[index];
    final purchaseId = IdGenerator.newId();
    final transactionId = IdGenerator.newId();
    final now = DateTime.now();
    final normalizedCategory = category.trim().isEmpty ? 'Saldo' : category.trim();
    final transaction = ElectronicBalanceTransaction(
      id: transactionId,
      accountId: accountId,
      type: ElectronicBalanceTransactionType.purchase,
      amount: amount,
      providerCost: amount,
      profit: 0,
      category: normalizedCategory,
      description: 'Compra de saldo',
      createdAt: now,
      purchaseId: purchaseId,
    );
    final purchase = PurchaseRecord(
      id: purchaseId,
      invoiceNumber: '',
      distributorName: account.companyName,
      arrivalAt: now,
      paymentMethod: 'Contado',
      purchaseType: 'electronic_balance',
      electronicBalanceAccountId: account.id,
      electronicBalanceTransactionId: transaction.id,
      electronicBalanceCategory: normalizedCategory,
      items: [
        PurchaseItemRecord(
          productId: 'electronic-balance:' + account.id,
          productName: 'Saldo electrónico',
          unit: normalizedCategory,
          barcode: '',
          unitCost: amount,
          quantity: 1,
          totalQuantity: 0,
          total: amount,
        ),
      ],
      subtotal: amount,
      total: amount,
    );
    final updatedAccount = account.copyWith(balance: account.balance + amount);
    _accounts[index] = updatedAccount;
    _transactions.add(transaction);
    notifyListeners();
    _persistAccount(updatedAccount);
    _persistTransaction(transaction);
    _purchasesProvider?.addPurchase(purchase);
    return true;
  }

  bool updatePurchase({required String purchaseId, required double amount, String? category}) {
    if (amount <= 0) return false;
    final transactionIndex = _transactions.indexWhere((t) => t.purchaseId == purchaseId && t.type == ElectronicBalanceTransactionType.purchase);
    if (transactionIndex < 0) return false;
    final transaction = _transactions[transactionIndex];
    final accountIndex = _accounts.indexWhere((a) => a.id == transaction.accountId);
    if (accountIndex < 0) return false;
    final account = _accounts[accountIndex];
    final nextCategory = category?.trim().isNotEmpty == true ? category!.trim() : transaction.category;
    final updatedTransaction = ElectronicBalanceTransaction(
      id: transaction.id,
      accountId: transaction.accountId,
      type: transaction.type,
      amount: amount,
      providerCost: amount,
      profit: 0,
      category: nextCategory,
      description: transaction.description,
      createdAt: transaction.createdAt,
      saleId: transaction.saleId,
      purchaseId: transaction.purchaseId,
      metadata: transaction.metadata.touch(),
    );
    _transactions[transactionIndex] = updatedTransaction;
    _accounts[accountIndex] = account.copyWith(balance: account.balance - transaction.amount + amount);
    notifyListeners();
    _persistAccount(_accounts[accountIndex]);
    _persistTransaction(updatedTransaction);
    PurchaseRecord? purchase;
    final purchasesProvider = _purchasesProvider;
    if (purchasesProvider != null) {
      for (final entry in purchasesProvider.purchases) {
        if (entry.id == purchaseId) {
          purchase = entry;
          break;
        }
      }
    }
    if (purchase != null) {
      final updatedItems = purchase.items.map((item) {
        if (item.productId != 'electronic-balance:' + transaction.accountId) {
          return item;
        }
        return PurchaseItemRecord(
          id: item.id,
          productId: item.productId,
          productName: item.productName,
          unit: nextCategory,
          barcode: item.barcode,
          imageData: item.imageData,
          unitCost: amount,
          quantity: 1,
          bonusQuantity: 0,
          unitsPerPresentation: 1,
          totalQuantity: 0,
          salePrice: item.salePrice,
          previousCost: item.previousCost,
          previousSalePrice: item.previousSalePrice,
          discount: item.discount,
          discountPercent: item.discountPercent,
          iva: item.iva,
          total: amount,
          effectiveUnitCost: amount,
          metadata: item.metadata.touch(),
        );
      }).toList();
      _purchasesProvider?.replacePurchase(
        purchase.copyWith(
          electronicBalanceCategory: nextCategory,
          items: updatedItems,
          subtotal: amount,
          total: amount,
        ),
      );
    }
    return true;
  }

  bool deletePurchase(String purchaseId) {
    final index = _transactions.indexWhere((t) => t.purchaseId == purchaseId && t.type == ElectronicBalanceTransactionType.purchase);
    if (index < 0) return false;
    final transaction = _transactions[index];
    final accountIndex = _accounts.indexWhere((a) => a.id == transaction.accountId);
    if (accountIndex < 0) return false;
    _accounts[accountIndex] = _accounts[accountIndex].copyWith(balance: _accounts[accountIndex].balance - transaction.amount);
    _transactions.removeAt(index);
    notifyListeners();
    _persistAccount(_accounts[accountIndex]);
    _persistDeleteTransaction(transaction.id);
    _purchasesProvider?.removePurchase(purchaseId);
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
    var totalBalanceDeductionCents = 0;
    for (final sale in sales) {
      final category = sale.category.trim();
      if (sale.amount <= 0 || sale.quantity <= 0 || !_service.isValidCategory(category)) return false;
      final amount = sale.amount * sale.quantity;
      pending.add(
        ElectronicBalanceTransaction(
          id: IdGenerator.newId(),
          accountId: accountId,
          type: ElectronicBalanceTransactionType.sale,
          amount: amount,
          providerCost: _service.providerCostForSale(
            account: account,
            category: category,
            amount: sale.amount,
          ) * sale.quantity,
          profit: _service.profitForSale(
            account: account,
            category: category,
            amount: sale.amount,
          ) * sale.quantity,
          category: category,
          description: sale.description.trim(),
          createdAt: now,
          saleId: saleId,
        ),
      );
      // The provider commission is profit; the electronic balance is
      // consumed by the full face value of the recharge.
      totalBalanceDeductionCents += _toCents(amount);
    }
    final updatedAccount = account.copyWith(
      balance: _fromCents(_toCents(account.balance) - totalBalanceDeductionCents),
    );
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
    final byAccountCents = <String, int>{};
    for (final transaction in matching) {
      byAccountCents[transaction.accountId] =
          (byAccountCents[transaction.accountId] ?? 0) + _toCents(transaction.amount);
    }
    for (final entry in byAccountCents.entries) {
      final index = _accounts.indexWhere((a) => a.id == entry.key);
      if (index < 0) return false;
      final account = _accounts[index].copyWith(
        balance: _fromCents(_toCents(_accounts[index].balance) + entry.value),
      );
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

    // Rebuild each balance from the transaction ledger. A sale consumes
    // its full face value; the commission is tracked separately as profit.
    // This also repairs balances produced by the previous implementation,
    // which deducted providerCost (amount minus commission).
    for (var i = 0; i < _accounts.length; i++) {
      final account = _accounts[i];
      final accountTransactions = _transactions.where(
        (transaction) => transaction.accountId == account.id,
      );
      if (accountTransactions.isEmpty) continue;

      var balanceCents = 0;
      for (final transaction in accountTransactions) {
        final amountCents = _toCents(transaction.amount);
        if (transaction.type == ElectronicBalanceTransactionType.purchase) {
          balanceCents += amountCents;
        } else {
          balanceCents -= amountCents;
        }
      }

      final expectedBalance = _fromCents(balanceCents);
      if ((account.balance - expectedBalance).abs() > 0.000001) {
        final corrected = account.copyWith(
          balance: expectedBalance,
          touchMetadata: false,
        );
        _accounts[i] = corrected;
        _persistAccount(corrected);
      }
    }

    _loaded = true;
    if (_accounts.isNotEmpty || _transactions.isNotEmpty) notifyListeners();
  }

  static int _toCents(double amount) => (amount * 100).round();

  static double _fromCents(int cents) => cents / 100.0;

  void _persistAccount(ElectronicBalanceAccount account) { _accountRepository?.save(account).catchError((_) {}); }
  void _persistTransaction(ElectronicBalanceTransaction transaction) { _transactionRepository?.save(transaction).catchError((_) {}); }
  void _persistDeleteAccount(String id) { _accountRepository?.delete(id).catchError((_) {}); }
  void _persistDeleteTransaction(String id) { _transactionRepository?.delete(id).catchError((_) {}); }
}
