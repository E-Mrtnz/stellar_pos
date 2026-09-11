import 'package:stellar_pos/core/data/repositories/sale_repository.dart';
import 'package:stellar_pos/core/models/electronic_balance_sale.dart';
import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/providers/electronic_balance_provider.dart';
import 'package:stellar_pos/core/providers/product_provider.dart';
import 'package:stellar_pos/core/providers/sales_provider.dart';

/// Extends the sales state with the date selected for a new sale and
/// persistence-aware date corrections for existing sales.
class DateAwareSalesProvider extends SalesProvider {
  final SaleRepository _saleRepository;
  DateTime _selectedSaleDate = _dateOnly(DateTime.now());

  DateAwareSalesProvider({required SaleRepository repository})
      : _saleRepository = repository,
        super(repository: repository);

  DateTime get selectedSaleDate => _selectedSaleDate;

  void setSelectedSaleDate(DateTime value) {
    _selectedSaleDate = _dateOnly(value);
    notifyListeners();
  }

  @override
  SaleRecord createSale({
    required Map<String, int> cartQuantities,
    required ProductProvider productProvider,
    required String paymentMethodLabel,
    required String? clientId,
    required String clientName,
    required double subtotal,
    required double discountPercent,
    required double discountAmount,
    required double cardFeeAmount,
    required double total,
    required double received,
    required double change,
    List<ElectronicBalanceCartSale> electronicSales = const [],
    ElectronicBalanceProvider? electronicBalanceProvider,
  }) {
    SaleRecord.setCreationDateOverride(_selectedSaleDate);
    try {
      return super.createSale(
        cartQuantities: cartQuantities,
        productProvider: productProvider,
        paymentMethodLabel: paymentMethodLabel,
        clientId: clientId,
        clientName: clientName,
        subtotal: subtotal,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        cardFeeAmount: cardFeeAmount,
        total: total,
        received: received,
        change: change,
        electronicSales: electronicSales,
        electronicBalanceProvider: electronicBalanceProvider,
      );
    } finally {
      SaleRecord.clearCreationDateOverride();
      _selectedSaleDate = _dateOnly(DateTime.now());
      notifyListeners();
    }
  }

  Future<SaleRecord?> updateSaleDate({
    required String saleId,
    required DateTime date,
  }) async {
    final index = sales.indexWhere((sale) => sale.id == saleId);
    if (index < 0) return null;

    final sale = sales[index];
    final updatedDate = _mergeDateWithTime(date, sale.createdAt);
    if (_sameDate(updatedDate, sale.createdAt)) return sale;

    final updated = sale.copyWith(
      createdAt: updatedDate,
      metadata: sale.metadata.touch(),
    );
    await _saleRepository.save(updated);

    final baseSales = super.sales;
    final baseIndex = baseSales.indexWhere((item) => item.id == saleId);
    if (baseIndex >= 0) {
      baseSales[baseIndex].createdAt = updated.createdAt;
    }

    notifyListeners();
    return updated;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _mergeDateWithTime(DateTime date, DateTime timeSource) =>
      DateTime(
        date.year,
        date.month,
        date.day,
        timeSource.hour,
        timeSource.minute,
        timeSource.second,
        timeSource.millisecond,
        timeSource.microsecond,
      );

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
