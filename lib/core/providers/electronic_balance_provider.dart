import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/electronic_balance.dart';

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
  final List<ElectronicBalanceAccount> _accounts = [];
  final List<ElectronicBalanceTransaction> _transactions = [];

  List<ElectronicBalanceAccount> get accounts => List.unmodifiable(_accounts);
  List<ElectronicBalanceTransaction> get transactions =>
      List.unmodifiable(_transactions);

  ElectronicBalanceAccount? findAccount(String id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  bool addAccount({
    required String companyName,
    required double commissionRate,
  }) {
    final name = companyName.trim();
    if (name.isEmpty || commissionRate < 0 || commissionRate > 100) {
      return false;
    }

    final exists = _accounts.any(
      (account) => account.companyName.toLowerCase() == name.toLowerCase(),
    );
    if (exists) return false;

    _accounts.add(
      ElectronicBalanceAccount(
        id: _newId(),
        companyName: name,
        commissionRate: commissionRate,
        balance: 0,
      ),
    );
    notifyListeners();
    return true;
  }

  bool updateAccount({
    required String id,
    required String companyName,
    required double commissionRate,
  }) {
    final index = _accounts.indexWhere((account) => account.id == id);
    final name = companyName.trim();
    if (index < 0 || name.isEmpty || commissionRate < 0 || commissionRate > 100) {
      return false;
    }

    final duplicate = _accounts.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          entry.value.companyName.toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) return false;

    _accounts[index] = _accounts[index].copyWith(
      companyName: name,
      commissionRate: commissionRate,
    );
    notifyListeners();
    return true;
  }

  bool removeAccount(String id) {
    if (_transactions.any((transaction) => transaction.accountId == id)) {
      return false;
    }

    final before = _accounts.length;
    _accounts.removeWhere((account) => account.id == id);
    if (_accounts.length == before) return false;

    notifyListeners();
    return true;
  }

  bool setSaleOptions({
    required String accountId,
    required List<ElectronicBalanceSaleOption> options,
  }) {
    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index < 0) return false;

    final normalized = <ElectronicBalanceSaleOption>[];
    final seen = <String>{};

    for (final option in options) {
      if (option.amount <= 0) continue;
      final category = option.category.trim();
      if (!{'Saldo', 'Internet', 'Llamada'}.contains(category)) continue;

      final key = '$category|${option.amount.toStringAsFixed(4)}';
      if (seen.add(key)) {
        normalized.add(
          ElectronicBalanceSaleOption(
            category: category,
            amount: option.amount,
          ),
        );
      }
    }

    normalized.sort((a, b) {
      final categoryCompare = _categoryOrder(a.category)
          .compareTo(_categoryOrder(b.category));
      if (categoryCompare != 0) return categoryCompare;
      return a.amount.compareTo(b.amount);
    });

    _accounts[index] = _accounts[index].copyWith(saleOptions: normalized);
    notifyListeners();
    return true;
  }

  /// Adds face-value balance. The provider cost is calculated using the
  /// company's commission, e.g. $20 at 5% costs $19 and leaves $20 available.
  bool registerPurchase({
    required String accountId,
    required double amount,
  }) {
    if (amount <= 0) return false;

    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index < 0) return false;

    final account = _accounts[index];
    final profit = amount * account.commissionMultiplier;
    final providerCost = amount - profit;

    _accounts[index] = account.copyWith(
      balance: account.balance + amount,
    );

    _transactions.add(
      ElectronicBalanceTransaction(
        id: _newId(),
        accountId: accountId,
        type: ElectronicBalanceTransactionType.purchase,
        amount: amount,
        providerCost: providerCost,
        profit: profit,
        category: 'Compra de saldo',
        description: 'Recarga de saldo',
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
    return true;
  }

  /// Consumes face-value balance. Negative balance is intentionally allowed,
  /// matching the physical-product inventory behavior.
  bool registerSale({
    required String accountId,
    required double amount,
    required String category,
    String description = '',
  }) {
    return registerSales(
      accountId: accountId,
      sales: [
        ElectronicBalanceSale(
          amount: amount,
          quantity: 1,
          category: category,
          description: description,
        ),
      ],
    );
  }

  /// Registers several selected electronic sales in one operation.
  /// Each selected option remains an individual transaction, while the
  /// account balance is reduced by the combined face value.
  bool registerSales({
    required String accountId,
    required List<ElectronicBalanceSale> sales,
  }) {
    if (sales.isEmpty) return false;

    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index < 0) return false;

    final account = _accounts[index];
    final now = DateTime.now();
    final pending = <ElectronicBalanceTransaction>[];
    var totalAmount = 0.0;

    for (final sale in sales) {
      if (sale.amount <= 0 || sale.quantity <= 0) return false;

      final category = sale.category.trim();
      if (!{'Saldo', 'Internet', 'Llamada'}.contains(category)) return false;

      final amount = sale.amount * sale.quantity;
      final profit = amount * account.commissionMultiplier;
      final providerCost = amount - profit;
      totalAmount += amount;

      pending.add(
        ElectronicBalanceTransaction(
          id: _newId(),
          accountId: accountId,
          type: ElectronicBalanceTransactionType.sale,
          amount: amount,
          providerCost: providerCost,
          profit: profit,
          category: category,
          description: sale.description.trim(),
          createdAt: now,
        ),
      );
    }

    _accounts[index] = account.copyWith(
      balance: account.balance - totalAmount,
    );
    _transactions.addAll(pending);

    notifyListeners();
    return true;
  }

  double totalPurchased(String accountId) {
    return _transactions
        .where(
          (transaction) =>
              transaction.accountId == accountId &&
              transaction.type == ElectronicBalanceTransactionType.purchase,
        )
        .fold(0, (sum, transaction) => sum + transaction.amount);
  }

  double totalSold(String accountId) {
    return _transactions
        .where(
          (transaction) =>
              transaction.accountId == accountId &&
              transaction.type == ElectronicBalanceTransactionType.sale,
        )
        .fold(0, (sum, transaction) => sum + transaction.amount);
  }

  double totalProfit(String accountId) {
    return _transactions
        .where(
          (transaction) =>
              transaction.accountId == accountId &&
              transaction.type == ElectronicBalanceTransactionType.sale,
        )
        .fold(0, (sum, transaction) => sum + transaction.profit);
  }

  List<ElectronicBalanceTransaction> transactionsFor(String accountId) {
    return _transactions
        .where((transaction) => transaction.accountId == accountId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int _categoryOrder(String category) {
    switch (category) {
      case 'Saldo':
        return 0;
      case 'Internet':
        return 1;
      case 'Llamada':
        return 2;
      default:
        return 99;
    }
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
