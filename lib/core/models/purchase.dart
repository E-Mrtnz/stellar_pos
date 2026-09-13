import 'package:stellar_pos/core/models/sync_metadata.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class PurchaseItemRecord implements SyncableEntity {
  @override
  final String id;
  final String productId;
  final String productName;
  final String unit;
  final String barcode;
  final String imageData;
  final double unitCost;
  final int quantity;
  final int bonusQuantity;
  final int totalQuantity;
  final double salePrice;
  final double discount;
  final double total;
  final double effectiveUnitCost;
  @override
  final SyncMetadata metadata;

  PurchaseItemRecord({
    String? id,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.barcode,
    this.imageData = '',
    required this.unitCost,
    required this.quantity,
    this.bonusQuantity = 0,
    int? totalQuantity,
    this.salePrice = 0,
    this.discount = 0,
    required this.total,
    double? effectiveUnitCost,
    SyncMetadata? metadata,
  })  : id = id ?? IdGenerator.newId(),
        totalQuantity = totalQuantity ?? quantity + bonusQuantity,
        effectiveUnitCost = effectiveUnitCost ??
            ((quantity + bonusQuantity) <= 0
                ? 0
                : total / (quantity + bonusQuantity)),
        metadata = metadata ?? SyncMetadata.initial();

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'unit': unit,
        'barcode': barcode,
        'imageData': imageData,
        'unitCost': unitCost,
        'quantity': quantity,
        'bonusQuantity': bonusQuantity,
        'totalQuantity': totalQuantity,
        'salePrice': salePrice,
        'discount': discount,
        'total': total,
        'effectiveUnitCost': effectiveUnitCost,
        'metadata': metadata.toMap(),
      };

  factory PurchaseItemRecord.fromMap(Map<String, dynamic> map) =>
      PurchaseItemRecord(
        id: map['id']?.toString(),
        productId: map['productId']?.toString() ?? '',
        productName: map['productName']?.toString() ?? '',
        unit: map['unit']?.toString() ?? '',
        barcode: map['barcode']?.toString() ?? '',
        imageData: map['imageData']?.toString() ?? '',
        unitCost: _double(map['unitCost']),
        quantity: _int(map['quantity']),
        bonusQuantity: _int(map['bonusQuantity']),
        totalQuantity: map.containsKey('totalQuantity')
            ? _int(map['totalQuantity'])
            : _int(map['quantity']) + _int(map['bonusQuantity']),
        salePrice: _double(map['salePrice']),
        discount: _double(map['discount']),
        total: _double(map['total']),
        effectiveUnitCost: map.containsKey('effectiveUnitCost')
            ? _double(map['effectiveUnitCost'])
            : null,
        metadata: _metadata(map['metadata']),
      );

  static double _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;

  static int _int(dynamic value) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;

  static SyncMetadata _metadata(dynamic value) => value is Map
      ? SyncMetadata.fromMap(Map<String, dynamic>.from(value))
      : SyncMetadata.initial();
}

class PurchaseRecord implements SyncableEntity {
  @override
  final String id;
  final String invoiceNumber;
  final String distributorName;
  final DateTime arrivalAt;
  final String paymentMethod;
  final List<PurchaseItemRecord> items;
  final double subtotal;
  final double discount;
  final double total;
  @override
  final SyncMetadata metadata;

  PurchaseRecord({
    required this.id,
    required this.invoiceNumber,
    required this.distributorName,
    required this.arrivalAt,
    required this.paymentMethod,
    required List<PurchaseItemRecord> items,
    required this.subtotal,
    this.discount = 0,
    required this.total,
    SyncMetadata? metadata,
  }) : items = List.unmodifiable(items),
       metadata = metadata ??
            SyncMetadata(
              createdAt: arrivalAt.toUtc(),
              updatedAt: arrivalAt.toUtc(),
            );

  int get itemCount => items.fold(0, (sum, item) => sum + item.totalQuantity);

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'distributorName': distributorName,
        'arrivalAt': arrivalAt.toIso8601String(),
        'paymentMethod': paymentMethod,
        'items': items.map((item) => item.toMap()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'metadata': metadata.toMap(),
      };

  factory PurchaseRecord.fromMap(Map<String, dynamic> map) => PurchaseRecord(
        id: map['id']?.toString() ?? '',
        invoiceNumber: map['invoiceNumber']?.toString() ?? '',
        distributorName: map['distributorName']?.toString() ?? '',
        arrivalAt: _date(map['arrivalAt']),
        paymentMethod: map['paymentMethod']?.toString() ?? 'Contado',
        items: _items(map['items']),
        subtotal: _double(map['subtotal']),
        discount: _double(map['discount']),
        total: _double(map['total']),
        metadata: _metadata(map['metadata']),
      );

  static List<PurchaseItemRecord> _items(dynamic value) => value is Iterable
      ? value
          .whereType<Map>()
          .map((item) => PurchaseItemRecord.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList()
      : const [];

  static DateTime _date(dynamic value) => value is DateTime
      ? value
      : DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();

  static double _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;

  static SyncMetadata _metadata(dynamic value) => value is Map
      ? SyncMetadata.fromMap(Map<String, dynamic>.from(value))
      : SyncMetadata.initial();
}
