class PurchaseItemRecord {
  final String productId;
  final String productName;
  final String unit;
  final String barcode;
  final String imageData;
  final double unitCost;
  final int quantity;
  final double total;

  const PurchaseItemRecord({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.barcode,
    this.imageData = '',
    required this.unitCost,
    required this.quantity,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'unit': unit,
        'barcode': barcode,
        'imageData': imageData,
        'unitCost': unitCost,
        'quantity': quantity,
        'total': total,
      };
}

class PurchaseRecord {
  final String id;
  final String invoiceNumber;
  final String distributorName;
  final DateTime purchasedAt;
  final DateTime? arrivalAt;
  final String paymentMethod;
  final List<PurchaseItemRecord> items;
  final double subtotal;
  final double total;

  const PurchaseRecord({
    required this.id,
    required this.invoiceNumber,
    required this.distributorName,
    required this.purchasedAt,
    required this.arrivalAt,
    required this.paymentMethod,
    required this.items,
    required this.subtotal,
    required this.total,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'distributorName': distributorName,
        'purchasedAt': purchasedAt.toIso8601String(),
        'arrivalAt': arrivalAt?.toIso8601String(),
        'paymentMethod': paymentMethod,
        'items': items.map((item) => item.toMap()).toList(),
        'subtotal': subtotal,
        'total': total,
      };
}
