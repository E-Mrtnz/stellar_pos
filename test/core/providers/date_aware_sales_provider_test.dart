import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/data/repositories/sale_repository.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/date_aware_sales_provider.dart';

void main() {
  group('DateAwareSalesProvider.updateSaleDate', () {
    late _InMemorySaleRepository repository;
    late DateAwareSalesProvider provider;

    setUp(() async {
      repository = _InMemorySaleRepository([
        _sale('sale-1', DateTime(2026, 10, 20, 9, 35, 42)),
        _sale('sale-2', DateTime(2026, 10, 21, 14, 10, 5)),
      ]);
      provider = DateAwareSalesProvider(repository: repository);
      await provider.load();
    });

    tearDown(() => provider.dispose());

    test('persists the new historical date and preserves the sale time', () async {
      final original = provider.sales.first;
      final originalTime = original.createdAt;

      final updated = await provider.updateSaleDate(
        saleId: 'sale-1',
        date: DateTime(2026, 10, 25, 23, 59),
      );

      expect(updated, isNotNull);
      expect(updated!.createdAt, DateTime(2026, 10, 25, 9, 35, 42));
      expect(repository.savedIds, ['sale-1']);
      expect(repository.records.first.createdAt, updated.createdAt);
      expect(provider.sales.first.createdAt, updated.createdAt);
      expect(provider.sales.first.metadata.updatedAt,
          updated.metadata.updatedAt);
      expect(originalTime.hour, 9);
      expect(provider.sales.last.createdAt, DateTime(2026, 10, 21, 14, 10, 5));
    });

    test('changing one sale never changes another sale', () async {
      final untouched = provider.sales.last;
      final untouchedDate = untouched.createdAt;
      final untouchedMetadata = untouched.metadata.updatedAt;

      await provider.updateSaleDate(
        saleId: 'sale-1',
        date: DateTime(2026, 10, 26),
      );

      expect(provider.sales.last.createdAt, untouchedDate);
      expect(provider.sales.last.metadata.updatedAt, untouchedMetadata);
      expect(repository.savedIds, ['sale-1']);
    });

    test('does not write when the selected calendar date is unchanged', () async {
      final sale = provider.sales.first;

      final result = await provider.updateSaleDate(
        saleId: sale.id,
        date: DateTime(2026, 10, 20, 22),
      );

      expect(identical(result, sale), isTrue);
      expect(repository.savedIds, isEmpty);
      expect(sale.createdAt, DateTime(2026, 10, 20, 9, 35, 42));
    });

    test('returns null and does not write for an unknown sale', () async {
      final result = await provider.updateSaleDate(
        saleId: 'missing-sale',
        date: DateTime(2026, 10, 25),
      );

      expect(result, isNull);
      expect(repository.savedIds, isEmpty);
      expect(provider.sales, hasLength(2));
    });
  });
}

SaleRecord _sale(String id, DateTime createdAt) => SaleRecord(
      id: id,
      ticketNumber: id,
      createdAt: createdAt,
      clientId: null,
      clientName: 'Cliente',
      paymentMethod: 'Efectivo',
      items: const [],
      subtotal: 10,
      discountPercent: 0,
      discountAmount: 0,
      cardFeeAmount: 0,
      total: 10,
      received: 10,
      change: 0,
    );

class _InMemorySaleRepository implements SaleRepository {
  _InMemorySaleRepository(this.records);

  final List<SaleRecord> records;
  final List<String> savedIds = [];

  @override
  Future<List<SaleRecord>> getAll() async => List.of(records);

  @override
  Future<SaleRecord?> getById(String id) async {
    for (final sale in records) {
      if (sale.id == id) return sale;
    }
    return null;
  }

  @override
  Future<void> save(SaleRecord entity) async {
    savedIds.add(entity.id);
    final index = records.indexWhere((sale) => sale.id == entity.id);
    if (index < 0) {
      records.add(entity);
    } else {
      records[index] = entity;
    }
  }

  @override
  Future<void> delete(String id) async {
    records.removeWhere((sale) => sale.id == id);
  }
}
