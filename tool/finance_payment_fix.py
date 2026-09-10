from pathlib import Path
import re

root = Path('.')

# Debt movement: distinguish the initial payment captured with a credit sale.
path = root / 'lib/core/models/debt.dart'
text = path.read_text()
text = text.replace(
    '  final String? reference;\n  @override\n  final SyncMetadata metadata;',
    '  final String? reference;\n  final bool isInitialPayment;\n  @override\n  final SyncMetadata metadata;',
)
text = text.replace(
    '    this.reference,\n    SyncMetadata? metadata,',
    '    this.reference,\n    this.isInitialPayment = false,\n    SyncMetadata? metadata,',
)
text = text.replace(
    "        'reference': reference,\n        'metadata': metadata.toMap(),",
    "        'reference': reference,\n        'isInitialPayment': isInitialPayment,\n        'metadata': metadata.toMap(),",
)
text = text.replace(
    "        reference: map['reference']?.toString(),\n        metadata: _metadata(map['metadata']),",
    "        reference: map['reference']?.toString(),\n        isInitialPayment: _bool(map['isInitialPayment']),\n        metadata: _metadata(map['metadata']),",
)
if 'static bool _bool(dynamic value)' not in text:
    marker = '  static DebtMovementType _type(dynamic value) =>'
    text = text.replace(
        marker,
        "  static bool _bool(dynamic value) => value is bool\n      ? value\n      : ['true', '1', 'si', 'sí'].contains(value?.toString().toLowerCase());\n\n" + marker,
    )
path.write_text(text)

# Annulled credit sales must not remain debt.
path = root / 'lib/core/domain/services/debt_service.dart'
text = path.read_text()
old = "  List<SaleRecord> creditSales(Iterable<SaleRecord> sales) => sales\n      .where((sale) => sale.paymentMethod == 'Fiado' && sale.clientId != null)"
new = "  List<SaleRecord> creditSales(Iterable<SaleRecord> sales) => sales\n      .where((sale) =>\n          sale.paymentMethod == 'Fiado' &&\n          sale.clientId != null &&\n          !sale.isAnnulled)"
if old not in text:
    raise SystemExit('debt_service.dart: creditSales marker not found')
text = text.replace(old, new)
path.write_text(text)

# DebtProvider: valid payments only, linked to active credit sales.
path = root / 'lib/core/providers/debt_provider.dart'
text = path.read_text()
text = text.replace(
    '  double get totalPaid => _service.totalPaid(_payments);',
    '  double get totalPaid => _service.totalPaid(_validPayments);',
)
text = text.replace(
    '  double paidForClient(String clientId) => _service.paidForClient(clientId, _payments);',
    '  double paidForClient(String clientId) =>\n      _service.paidForClient(clientId, _validPayments);',
)

record_pattern = re.compile(r"  bool recordPayment\(\{.*?\n  void syncInitialPayment", re.S)
record_replacement = '''  bool recordPayment({required String clientId, required String clientName, required double amount, double? maxAmount}) {
    final account = accountFor(clientId);
    final appliedAmount = _service.appliedPayment(
      amount: amount,
      remaining: account?.remaining ?? 0,
      maxAmount: maxAmount,
    );
    if (clientId.trim().isEmpty || appliedAmount <= 0) return false;

    final creditSales = _service
        .creditSales(_salesProvider.sales)
        .where((sale) => sale.clientId == clientId && sale.effectiveTotal > 0.005)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (creditSales.isEmpty) return false;

    final paidBySale = _allocatedPaidBySale(creditSales, clientId);
    var remaining = appliedAmount;
    var savedAny = false;
    final now = DateTime.now();

    for (final sale in creditSales) {
      if (remaining <= 0.005) break;
      final outstanding =
          (sale.effectiveTotal - (paidBySale[sale.id] ?? 0)).clamp(0, double.infinity).toDouble();
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

  void syncInitialPayment'''
text, count = record_pattern.subn(record_replacement, text, count=1)
if count != 1:
    raise SystemExit('debt_provider.dart: recordPayment marker not found')

sync_pattern = re.compile(r"  void syncInitialPayment\(\{.*?\n  void renameClient", re.S)
sync_replacement = '''  void syncInitialPayment({required String saleId, required String clientId, required String clientName, required double amount}) {
    dynamic sale;
    for (final candidate in _salesProvider.sales) {
      if (candidate.id == saleId) {
        sale = candidate;
        break;
      }
    }
    if (sale == null || sale.paymentMethod != 'Fiado') return;

    final existing = _payments
        .where((payment) =>
            payment.reference == saleId && payment.isInitialPayment)
        .toList();
    final originalCreatedAt = existing.isEmpty ? null : existing.first.createdAt;
    _payments.removeWhere((payment) =>
        payment.reference == saleId && payment.isInitialPayment);
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

  void renameClient'''
text, count = sync_pattern.subn(sync_replacement, text, count=1)
if count != 1:
    raise SystemExit('debt_provider.dart: syncInitialPayment marker not found')

text = text.replace(
    'type: movement.type, amount: movement.amount, createdAt: movement.createdAt, reference: movement.reference, metadata: movement.metadata.touch()',
    'type: movement.type, amount: movement.amount, createdAt: movement.createdAt, reference: movement.reference, isInitialPayment: movement.isInitialPayment, metadata: movement.metadata.touch()',
)

helper_marker = '  @override void dispose()'
helper = '''  Iterable<DebtMovement> get _validPayments {
    final activeSales = _service.creditSales(_salesProvider.sales);
    final byId = <String, SaleRecord>{for (final sale in activeSales) sale.id: sale};
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
    final payments = _validPayments
        .where((payment) => payment.clientId == clientId)
        .toList()
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
        final outstanding =
            (sale.effectiveTotal - (paid[sale.id] ?? 0)).clamp(0, double.infinity).toDouble();
        if (outstanding <= 0.005) continue;
        final allocation = remaining > outstanding ? outstanding : remaining;
        paid[sale.id] = (paid[sale.id] ?? 0) + allocation;
        remaining -= allocation;
      }
    }
    return paid;
  }

'''
if helper_marker not in text:
    raise SystemExit('debt_provider.dart: dispose marker not found')
text = text.replace(helper_marker, helper + helper_marker, 1)
path.write_text(text)

# Sales screen: count later payments, including referenced ones, but not
# initial payments or payments attached to deleted/annulled sales.
path = root / 'lib/presentation/sales/sales_layout.dart'
text = path.read_text()
later_pattern = re.compile(r"  double _laterPayments\(List<DebtMovement> movements, DateTimeRange range\) =>.*?;\n  int _effectiveItemCount", re.S)
later_replacement = '''  double _laterPayments(
    List<SaleRecord> sales,
    List<DebtMovement> movements,
    DateTimeRange range,
  ) {
    final activeCredits = sales
        .where(
          (sale) =>
              sale.paymentMethod == AppStrings.creditPayment &&
              sale.clientId != null &&
              !sale.isAnnulled,
        )
        .toList();
    final byId = <String, SaleRecord>{
      for (final sale in activeCredits) sale.id: sale,
    };
    final byClient = <String, List<SaleRecord>>{};
    for (final sale in activeCredits) {
      final clientId = sale.clientId;
      if (clientId != null) byClient.putIfAbsent(clientId, () => []).add(sale);
    }

    return movements
        .where(
          (movement) =>
              movement.type == DebtMovementType.payment &&
              !movement.isInitialPayment &&
              !movement.createdAt.isBefore(range.start) &&
              movement.createdAt.isBefore(range.end),
        )
        .fold(0.0, (sum, movement) {
          final reference = movement.reference?.trim();
          final valid = reference != null && reference.isNotEmpty
              ? byId[reference]?.clientId == movement.clientId
              : byClient[movement.clientId]?.any(
                    (sale) => !sale.createdAt.isAfter(movement.createdAt),
                  ) ??
                  false;
          return valid ? sum + movement.amount : sum;
        });
  }

  int _effectiveItemCount'''
text, count = later_pattern.subn(later_replacement, text, count=1)
if count != 1:
    raise SystemExit('sales_layout.dart: laterPayments marker not found')
text = text.replace(
    'final laterPayments = _laterPayments(debtProvider.movements, range);',
    'final laterPayments = _laterPayments(\n        salesProvider.sales,\n        debtProvider.movements,\n        range,\n      );',
)
path.write_text(text)

# Focused regression test.
test_path = root / 'test/core/models/debt_serialization_test.dart'
test_text = test_path.read_text()
if 'DebtMovement preserves initial payment flag' not in test_text:
    if 'void main()' not in test_text:
        raise SystemExit('debt_serialization_test.dart: unexpected structure')
    test_text = re.sub(
        r'\n\}\s*$',
        '''

  test('DebtMovement preserves initial payment flag', () {
    final movement = DebtMovement(
      id: 'payment-1',
      clientId: 'client-1',
      clientName: 'Cliente',
      type: DebtMovementType.payment,
      amount: 1.25,
      createdAt: DateTime(2026, 9, 9, 10, 0),
      reference: 'sale-1',
      isInitialPayment: true,
    );

    final restored = DebtMovement.fromMap(movement.toMap());
    expect(restored.isInitialPayment, isTrue);
    expect(restored.reference, 'sale-1');
  });
}
''',
        test_text,
        count=1,
    )
    test_path.write_text(test_text)

print('Finance payment accounting fix staged.')
