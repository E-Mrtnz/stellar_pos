import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/data/repositories/debt_movement_repository.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/domain/services/debt_service.dart';
import 'package:stellar_pos/core/models/debt.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class DebtProvider extends ChangeNotifier {
  final SalesProvider _salesProvider;
  final DebtService _service;
  final Repository<DebtMovement>? _movementRepository;
  final List<DebtMovement> _payments = [];
  Future<void>? _loadFuture;
  bool _loaded = false;

  DebtProvider(
    this._salesProvider, {
    DebtService? service,
    Repository<DebtMovement>? movementRepository,
  }) : _service = service ?? AppDependencies.debt,
       _movementRepository = movementRepository {
    _salesProvider.addListener(_onSalesChanged);
  }

  List<DebtAccount> get accounts =>
      List.unmodifiable(_service.accounts(_salesProvider.sales, _validPayments));
  List<DebtMovement> get movements {
    final result = <DebtMovement>[
      ..._service
          .creditSales(_salesProvider.sales)
          .map(
            (sale) => DebtMovement(
              id: sale.id,
              clientId: sale.clientId ?? '',
              clientName: sale.clientName,
              type: DebtMovementType.debt,
              amount: sale.effectiveTotal,
              createdAt: sale.createdAt,
              reference: sale.ticketNumber,
            ),
          ),
      ..._payments,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(result);
  }

  double get totalDebt => _service.totalDebt(_salesProvider.sales);
  double get totalPaid => _service.totalPaid(_validPayments);
  double get totalRemaining =>
      (totalDebt - totalPaid).clamp(0, double.infinity).toDouble();
  int get clientsWithDebt => accounts.where((a) => a.remaining > 0.005).length;
  DebtAccount? accountFor(String clientId) =>
      _service.accountFor(clientId, _salesProvider.sales, _validPayments);
  double paidForClient(String clientId) =>
      _service.paidForClient(clientId, _validPayments);

  Future<void> load() {
    if (_loaded) return Future.value();
    final existing = _loadFuture;
    if (existing != null) return existing;
    final future = _loadFromRepository();
    _loadFuture = future;
    return future;
  }

  bool recordPayment({
    required String clientId,
    required String clientName,
    required double amount,
    double? maxAmount,
  }) {
    final account = accountFor(clientId);
    final appliedAmount = _service.appliedPayment(
      amount: amount,
      remaining: account?.remaining ?? 0,
      maxAmount: maxAmount,
    );
    if (clientId.trim().isEmpty || appliedAmount <= 0) return false;

    final creditSales =
        _service
            .creditSales(_salesProvider.sales)
            .where(
              (sale) =>
                  sale.clientId == clientId && sale.effectiveTotal > 0.005,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (creditSales.isEmpty) return false;

    final paidBySale = _allocatedPaidBySale(creditSales, clientId);
    var remaining = appliedAmount;
    var savedAny = false;
    final now = DateTime.now();

    for (final sale in creditSales) {
      if (remaining <= 0.005) break;
      final outstanding = (sale.effectiveTotal - (paidBySale[sale.id] ?? 0))
          .clamp(0, double.infinity)
          .toDouble();
      if (outstanding <= 0.005) continue;
      final allocation = remaining > outstanding ? outstanding : remaining;
      if (allocation <= 0.005) continue;

      final payment = DebtMovement(
        id: IdGenerator.newId(),
        clientId: clientId,
        clientName: clientName,
        type: DebtMovementType.payment,
        amount: allocation,
        createdAt: now,
        reference: sale.id,
        isInitialPayment: false,
      );
      _payments.add(payment);
      unawaited(_movementRepository?.save(payment));
      savedAny = true;
      remaining -= allocation;
    }

    if (!savedAny) return false;
    notifyListeners();
    return true;
  }

  void syncInitialPayment({
    required String saleId,
    required String clientId,
    required String clientName,
    required double amount,
  }) {
    dynamic sale;
    for (final candidate in _salesProvider.sales) {
      if (candidate.id == saleId) {
        sale = candidate;
        break;
      }
    }
    if (sale == null || sale.paymentMethod != 'Fiado') return;

    final existing = _payments
        .where(
          (payment) => payment.reference == saleId && payment.isInitialPayment,
        )
        .toList();
    final originalCreatedAt = existing.isEmpty
        ? null
        : existing.first.createdAt;
    _payments.removeWhere(
      (payment) => payment.reference == saleId && payment.isInitialPayment,
    );
    for (final payment in existing) {
      unawaited(_movementRepository?.delete(payment.id));
    }

    final appliedAmount = amount.clamp(0, double.infinity).toDouble();
    if (appliedAmount > 0.005) {
      final payment = DebtMovement(
        id: IdGenerator.newId(),
        clientId: clientId,
        clientName: clientName,
        type: DebtMovementType.payment,
        amount: appliedAmount,
        createdAt: originalCreatedAt ?? DateTime.now(),
        reference: saleId,
        isInitialPayment: true,
      );
      _payments.add(payment);
      unawaited(_movementRepository?.save(payment));
    }
    notifyListeners();
  }

  void renameClient(String clientId, String clientName) {
    var changed = false;
    for (var i = 0; i < _payments.length; i++) {
      final movement = _payments[i];
      if (movement.clientId != clientId || movement.clientName == clientName)
        continue;
      final updated = DebtMovement(
        id: movement.id,
        clientId: movement.clientId,
        clientName: clientName,
        type: movement.type,
        amount: movement.amount,
        createdAt: movement.createdAt,
        reference: movement.reference,
        isInitialPayment: movement.isInitialPayment,
        metadata: movement.metadata.touch(),
      );
      _payments[i] = updated;
      unawaited(_movementRepository?.save(updated));
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Iterable<DebtMovement> get _validPayments {
    final activeSales = _service.creditSales(_salesProvider.sales);
    final byId = <String, SaleRecord>{
      for (final sale in activeSales) sale.id: sale,
    };
    final byClient = <String, List<SaleRecord>>{};
    for (final sale in activeSales) {
      final clientId = sale.clientId;
      if (clientId != null) byClient.putIfAbsent(clientId, () => []).add(sale);
    }

    return _payments.where((payment) {
      if (payment.type != DebtMovementType.payment) return false;
      final reference = payment.reference?.trim();
      if (reference != null && reference.isNotEmpty) {
        final sale = byId[reference];
        return sale != null && sale.clientId == payment.clientId;
      }

      // Legacy movements without a reference are only valid when there was
      // an active credit sale for that client at or before the payment time.
      // This prevents old orphaned test payments from contaminating finances.
      return byClient[payment.clientId]?.any(
            (sale) => !sale.createdAt.isAfter(payment.createdAt),
          ) ??
          false;
    });
  }

  Map<String, double> _allocatedPaidBySale(
    List<SaleRecord> sales,
    String clientId,
  ) {
    final paid = <String, double>{for (final sale in sales) sale.id: 0};
    final payments =
        _validPayments.where((payment) => payment.clientId == clientId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final payment in payments) {
      var remaining = payment.amount;
      final reference = payment.reference;
      if (reference != null && paid.containsKey(reference)) {
        paid[reference] = (paid[reference] ?? 0) + remaining;
        continue;
      }
      for (final sale in sales) {
        if (remaining <= 0.005) break;
        final outstanding = (sale.effectiveTotal - (paid[sale.id] ?? 0))
            .clamp(0, double.infinity)
            .toDouble();
        if (outstanding <= 0.005) continue;
        final allocation = remaining > outstanding ? outstanding : remaining;
        paid[sale.id] = (paid[sale.id] ?? 0) + allocation;
        remaining -= allocation;
      }
    }
    return paid;
  }

  @override
  void dispose() {
    _salesProvider.removeListener(_onSalesChanged);
    super.dispose();
  }

  void _onSalesChanged() => notifyListeners();

  Future<void> _loadFromRepository() async {
    await _salesProvider.load();
    final repository = _movementRepository;
    if (repository != null) {
      final stored = await repository.getAll();
      final byId = <String, DebtMovement>{
        for (final movement in _payments) movement.id: movement,
      };
      for (final movement in stored)
        byId.putIfAbsent(movement.id, () => movement);
      _payments
        ..clear()
        ..addAll(byId.values);
      if (stored.isNotEmpty) notifyListeners();
    }
    _loaded = true;
  }
}
