import 'package:stellar_pos/core/models/purchase.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class PurchaseService {
  const PurchaseService();

  String newPurchaseId() => IdGenerator.newId();

  double subtotal(Iterable<PurchaseItemRecord> items) =>
      items.fold(0.0, (sum, item) => sum + item.total);

  PurchaseRecord create({
    String? id,
    required String invoiceNumber,
    required String distributorName,
    required DateTime arrivalAt,
    required String paymentMethod,
    required List<PurchaseItemRecord> items,
  }) {
    if (items.isEmpty) {
      throw StateError('La compra debe contener al menos un producto.');
    }
    if (distributorName.trim().isEmpty) {
      throw StateError('La distribuidora es obligatoria.');
    }
    for (final item in items) {
      if (item.quantity <= 0 || item.unitCost < 0) {
        throw StateError('Los datos de un producto de compra no son válidos.');
      }
    }
    final total = subtotal(items);
    return PurchaseRecord(
      id: id ?? newPurchaseId(),
      invoiceNumber: invoiceNumber.trim(),
      distributorName: distributorName.trim(),
      arrivalAt: arrivalAt,
      paymentMethod: paymentMethod.trim(),
      items: List.unmodifiable(items),
      subtotal: total,
      total: total,
    );
  }
}
