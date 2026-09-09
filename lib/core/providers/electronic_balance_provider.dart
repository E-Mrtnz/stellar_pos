import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/electronic_balance.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class ElectronicBalanceSale {
  final double amount;
  final int quantity;
  final String category;
  final String description;

  const ElectronicBalanceSale({
    required this.amount,
    required this.quantity,
    required this.category,
    this.description = '',
  });
}

class ElectronicBalanceProvider extends ChangeNotifier {
  static const validCategories = ['Saldo', 'Internet', 'Llamada'];

  final List<ElectronicBalanceAccount> _accounts = [];
  final List<ElectronicBalanceTransaction> _transactions = [];

  List<ElectronicBalanceAccount> get accounts {
    final result = List<ElectronicBalanceAccount>.from(_accounts)
      ..sort((a, b) => a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()));
    return List.unmodifiable(result);
  }

  List<ElectronicBalanceTransaction> get transactions => List.unmodifiable(_transactions);

  ElectronicBalanceAccount? findAccount(String id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  bool addAccount({required String companyName, required double commissionRate}) {
    final name = companyName.trim();
    if (name.isEmpty || commissionRate < 0 || commissionRate > 100) return false;
    if (_accounts.any((a) => a.companyName.toLowerCase() == name.toLowerCase())) return false;
    _accounts.add(ElectronicBalanceAccount(
      id: IdGenerator.newId(),
      companyName: name,
      commissionRate: commissionRate,
      balance: 0,
    ));
    notifyListeners();
    return true;
  }

  bool updateAccount({required String id, required String companyName, required double commissionRate}) {
    final index = _accounts.indexWhere((a) => a.id == id);
    final name = companyName.trim();
    if (index < 0 || name.isEmpty || commissionRate < 0 || commissionRate > 100) return false;
    if (_accounts.asMap().entries.any((e) => e.key != index && e.value.companyName.toLowerCase() == name.toLowerCase())) return false;
    _accounts[index] = _accounts[index].copyWith(companyName: name, commissionRate: commissionRate);
    notifyListeners();
    return true;
  }

  bool removeAccount(String id) {
    if (_transactions.any((t) => t.accountId == id)) return false;
    final before = _accounts.length;
    _accounts.removeWhere((a) => a.id == id);
    if (before == _accounts.length) return false;
    notifyListeners();
    return true;
  }

  bool setSaleOptions({required String accountId, required List<ElectronicBalanceSaleOption> options}) {
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index < 0) return false;
    final normalized = <ElectronicBalanceSaleOption>[];
    final seen = <String>{};
    for (final option in options) {
      final category = option.category.trim();
      if (option.amount <= 0 || !validCategories.contains(category)) continue;
      if (seen.add('$category|${option.amount.toStringAsFixed(4)}')) {
        normalized.add(ElectronicBalanceSaleOption(category: category, amount: option.amount));
      }
    }
    normalized.sort((a, b) {
      final byCategory = _categoryOrder(a.category).compareTo(_categoryOrder(b.category));
      return byCategory == 0 ? a.amount.compareTo(b.amount) : byCategory;
    });
    _accounts[index] = _accounts[index].copyWith(saleOptions: normalized);
    notifyListeners();
    return true;
  }

  bool registerPurchase({required String accountId, required double amount}) {
    if (amount <= 0) return false;
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index < 0) return false;
    final account = _accounts[index];
    final profit = amount * account.commissionMultiplier;
    _accounts[index] = account.copyWith(balance: account.balance + amount);
    _transactions.add(ElectronicBalanceTransaction(
      id: IdGenerator.newId(),
      accountId: accountId,
      type: ElectronicBalanceTransactionType.purchase,
      amount: amount,
      providerCost: amount - profit,
      profit: profit,
      category: 'Compra de saldo',
      description: 'Recarga de saldo',
      createdAt: DateTime.now(),
    ));
    notifyListeners();
    return true;
  }

  bool registerSale({required String accountId, required double amount, required String category, String description = ''}) => registerSales(
        accountId: accountId,
        sales: [ElectronicBalanceSale(amount: amount, quantity: 1, category: category, description: description)],
      );

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
      if (sale.amount <= 0 || sale.quantity <= 0 || !validCategories.contains(category)) return false;
      final amount = sale.amount * sale.quantity;
      final profit = amount * account.commissionMultiplier;
      totalAmount += amount;
      pending.add(ElectronicBalanceTransaction(
        id: IdGenerator.newId(),
        accountId: accountId,
        type: ElectronicBalanceTransactionType.sale,
        amount: amount,
        providerCost: amount - profit,
        profit: profit,
        category: category,
        description: sale.description.trim(),
        createdAt: now,
        saleId: saleId,
      ));
    }
    _accounts[index] = account.copyWith(balance: account.balance - totalAmount);
    _transactions.addAll(pending);
    notifyListeners();
    return true;
  }

  bool reverseSale(String saleId) {
    final matching = _transactions.where((t) => t.saleId == saleId && t.type == ElectronicBalanceTransactionType.sale).toList();
    if (matching.isEmpty) return false;
    final byAccount = <String, double>{};
    for (final transaction in matching) {
      byAccount[transaction.accountId] = (byAccount[transaction.accountId] ?? 0) + transaction.amount;
    }
    for (final entry in byAccount.entries) {
      final index = _accounts.indexWhere((a) => a.id == entry.key);
      if (index < 0) return false;
      _accounts[index] = _accounts[index].copyWith(balance: _accounts[index].balance + entry.value);
    }
    _transactions.removeWhere((t) => t.saleId == saleId && t.type == ElectronicBalanceTransactionType.sale);
    notifyListeners();
    return true;
  }

  double totalPurchased(String id) => _transactions.where((t) => t.accountId == id && t.type == ElectronicBalanceTransactionType.purchase).fold(0, (sum, t) => sum + t.amount);
  double totalSold(String id) => _transactions.where((t) => t.accountId == id && t.type == ElectronicBalanceTransactionType.sale).fold(0, (sum, t) => sum + t.amount);
  double totalProfit(String id) => _transactions.where((t) => t.accountId == id && t.type == ElectronicBalanceTransactionType.sale).fold(0, (sum, t) => sum + t.profit);

  List<ElectronicBalanceTransaction> transactionsFor(String id) => _transactions.where((t) => t.accountId == id).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int _categoryOrder(String category) => validCategories.indexOf(category);
}
