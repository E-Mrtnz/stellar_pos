import 'package:stellar_pos/core/models/sale_ticket.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class SaleItemRecord implements SyncableEntity {
  @override
  final String id;
  final String productId;
  final String productName;
  final String unit;
  final String brand;
  final String barcode;
  final double cost;
  final double unitPrice;
  final int quantity;
  final double lineSubtotal;
  final double discount;
  final double lineTotal;
  final String imageData;
  final bool isElectronicBalance;
  final bool hasGroupPricing;
  final String? electronicBalanceAccountId;
  final String? electronicBalanceCategory;
  @override
  final SyncMetadata metadata;

  SaleItemRecord({
    String? id,
    required this.productId,
    required this.productName,
    required this.unit,
    this.brand = '',
    required this.barcode,
    required this.cost,
    required this.unitPrice,
    required this.quantity,
    required this.lineSubtotal,
    required this.discount,
    required this.lineTotal,
    this.imageData = '',
    this.isElectronicBalance = false,
    this.hasGroupPricing = false,
    this.electronicBalanceAccountId,
    this.electronicBalanceCategory,
    SyncMetadata? metadata,
  }) : id = id ?? IdGenerator.newId(),
       metadata = metadata ?? SyncMetadata.initial();

  Map<String, dynamic> toMap() => {
    'id': id, 'productId': productId, 'productName': productName,
    'unit': unit, 'brand': brand, 'barcode': barcode, 'cost': cost,
    'unitPrice': unitPrice, 'quantity': quantity, 'lineSubtotal': lineSubtotal,
    'discount': discount, 'lineTotal': lineTotal, 'imageData': imageData,
    'isElectronicBalance': isElectronicBalance, 'hasGroupPricing': hasGroupPricing,
    'electronicBalanceAccountId': electronicBalanceAccountId,
    'electronicBalanceCategory': electronicBalanceCategory,
    'metadata': metadata.toMap(),
  };

  factory SaleItemRecord.fromMap(Map<String, dynamic> map) => SaleItemRecord(
    id: map['id']?.toString(), productId: map['productId']?.toString() ?? '',
    productName: map['productName']?.toString() ?? '', unit: map['unit']?.toString() ?? '',
    brand: map['brand']?.toString() ?? '', barcode: map['barcode']?.toString() ?? '',
    cost: _double(map['cost']), unitPrice: _double(map['unitPrice']),
    quantity: _int(map['quantity']), lineSubtotal: _double(map['lineSubtotal']),
    discount: _double(map['discount']), lineTotal: _double(map['lineTotal']),
    imageData: map['imageData']?.toString() ?? '',
    isElectronicBalance: _bool(map['isElectronicBalance']),
    hasGroupPricing: _bool(map['hasGroupPricing']),
    electronicBalanceAccountId: map['electronicBalanceAccountId']?.toString(),
    electronicBalanceCategory: map['electronicBalanceCategory']?.toString(),
    metadata: _metadata(map['metadata']),
  );

  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
  static bool _bool(dynamic v) => v is bool ? v : ['true','1','si','sí'].contains(v?.toString().toLowerCase());
  static SyncMetadata _metadata(dynamic v) => v is Map ? SyncMetadata.fromMap(Map<String,dynamic>.from(v)) : SyncMetadata.initial();
}

class SaleRecord implements SyncableEntity {
  @override String id;
  String ticketNumber;
  DateTime createdAt;
  String? clientId;
  String clientName;
  String paymentMethod;
  List<SaleItemRecord> items;
  double subtotal;
  double discountPercent;
  double discountAmount;
  double cardFeeAmount;
  double total;
  double received;
  double change;
  @override SyncMetadata metadata;

  SaleRecord({
    required this.id, required this.ticketNumber, required this.createdAt,
    required this.clientId, required this.clientName, required this.paymentMethod,
    required this.items, required this.subtotal, required this.discountPercent,
    required this.discountAmount, required this.cardFeeAmount, required this.total,
    required this.received, required this.change, SyncMetadata? metadata,
  }) : metadata = metadata ?? SyncMetadata(createdAt: createdAt.toUtc(), updatedAt: createdAt.toUtc());

  SaleRecord copyWith({
    String? id, String? ticketNumber, DateTime? createdAt, String? clientId,
    String? clientName, String? paymentMethod, List<SaleItemRecord>? items,
    double? subtotal, double? discountPercent, double? discountAmount,
    double? cardFeeAmount, double? total, double? received, double? change,
    SyncMetadata? metadata, bool touchMetadata = false,
  }) => SaleRecord(
    id: id ?? this.id, ticketNumber: ticketNumber ?? this.ticketNumber,
    createdAt: createdAt ?? this.createdAt, clientId: clientId ?? this.clientId,
    clientName: clientName ?? this.clientName, paymentMethod: paymentMethod ?? this.paymentMethod,
    items: items ?? this.items, subtotal: subtotal ?? this.subtotal,
    discountPercent: discountPercent ?? this.discountPercent,
    discountAmount: discountAmount ?? this.discountAmount,
    cardFeeAmount: cardFeeAmount ?? this.cardFeeAmount, total: total ?? this.total,
    received: received ?? this.received, change: change ?? this.change,
    metadata: metadata ?? (touchMetadata ? this.metadata.touch() : this.metadata),
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'ticketNumber': ticketNumber, 'createdAt': createdAt.toIso8601String(),
    'clientId': clientId, 'clientName': clientName, 'paymentMethod': paymentMethod,
    'items': items.map((item) => item.toMap()).toList(), 'subtotal': subtotal,
    'discountPercent': discountPercent, 'discountAmount': discountAmount,
    'cardFeeAmount': cardFeeAmount, 'total': total, 'received': received,
    'change': change, 'metadata': metadata.toMap(),
  };

  factory SaleRecord.fromMap(Map<String,dynamic> map) => SaleRecord(
    id: map['id']?.toString() ?? IdGenerator.newId(), ticketNumber: map['ticketNumber']?.toString() ?? '',
    createdAt: _date(map['createdAt']), clientId: map['clientId']?.toString(),
    clientName: map['clientName']?.toString() ?? '', paymentMethod: map['paymentMethod']?.toString() ?? '',
    items: _items(map['items']), subtotal: _double(map['subtotal']),
    discountPercent: _double(map['discountPercent']), discountAmount: _double(map['discountAmount']),
    cardFeeAmount: _double(map['cardFeeAmount']), total: _double(map['total']),
    received: _double(map['received']), change: _double(map['change']), metadata: _metadata(map['metadata']),
  );

  SaleTicketData toTicketData() {
    final date='${createdAt.day.toString().padLeft(2,'0')}/${createdAt.month.toString().padLeft(2,'0')}/${createdAt.year}';
    final hour=createdAt.hour%12==0?12:createdAt.hour%12;
    final period=createdAt.hour>=12?'PM':'AM';
    final time='${hour.toString().padLeft(2,'0')}:${createdAt.minute.toString().padLeft(2,'0')} $period';
    return SaleTicketData(ticketNumber: ticketNumber,date: date,time: time,client: clientName,
      items: items.map((item)=>SaleTicketItem(quantity:item.quantity,description:item.productName,brand:item.brand,
        unitPrice:item.hasGroupPricing?item.lineTotal:item.unitPrice,discount:item.discount,total:item.lineTotal)).toList(growable:false),
      subtotal:subtotal,discount:discountAmount,cardFee:cardFeeAmount,total:total,paymentMethod:paymentMethod,received:received,change:change);
  }

  static List<SaleItemRecord> _items(dynamic v)=>v is Iterable?v.whereType<Map>().map((i)=>SaleItemRecord.fromMap(Map<String,dynamic>.from(i))).toList():const [];
  static DateTime _date(dynamic v)=>v is DateTime?v:DateTime.tryParse(v?.toString()??'')??DateTime.now();
  static double _double(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'')??0;
  static SyncMetadata _metadata(dynamic v)=>v is Map?SyncMetadata.fromMap(Map<String,dynamic>.from(v)):SyncMetadata.initial();
}
