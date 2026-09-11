import 'package:stellar_pos/core/models/sale_ticket.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

enum SaleStatus {
  completed,
  annulled,
}

enum SaleOperationType {
  returnItem,
  change,
}

class SaleOperationRecord {
  final String id;
  final SaleOperationType type;
  final DateTime createdAt;
  final List<SaleItemRecord> itemsOut;
  final List<SaleItemRecord> itemsIn;
  /// Positive = customer pays the difference. Negative = store refunds it.
  final double amountDelta;
  final String note;

  SaleOperationRecord({
    String? id,
    required this.type,
    required this.createdAt,
    this.itemsOut = const [],
    this.itemsIn = const [],
    required this.amountDelta,
    this.note = '',
  }) : id = id ?? IdGenerator.newId();

  String get label => type == SaleOperationType.change ? 'CAMBIO' : 'DEVOLUCIÓN';

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'itemsOut': itemsOut.map((item) => item.toMap()).toList(growable: false),
        'itemsIn': itemsIn.map((item) => item.toMap()).toList(growable: false),
        'amountDelta': amountDelta,
        'note': note,
      };

  factory SaleOperationRecord.fromMap(Map<String, dynamic> map) {
    final type = map['type']?.toString() == SaleOperationType.change.name
        ? SaleOperationType.change
        : SaleOperationType.returnItem;
    return SaleOperationRecord(
      id: map['id']?.toString(),
      type: type,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      itemsOut: _items(map['itemsOut']),
      itemsIn: _items(map['itemsIn']),
      amountDelta: _double(map['amountDelta']),
      note: map['note']?.toString() ?? '',
    );
  }

  static List<SaleItemRecord> _items(dynamic value) => value is Iterable
      ? value.whereType<Map>().map((item) => SaleItemRecord.fromMap(Map<String, dynamic>.from(item))).toList(growable: false)
      : const [];

  static double _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
}

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
    required String productName,
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
    bool isElectronicBalance = false,
    this.hasGroupPricing = false,
    String? electronicBalanceAccountId,
    String? electronicBalanceCategory,
    SyncMetadata? metadata,
  })  : id = id ?? IdGenerator.newId(),
        isElectronicBalance = isElectronicBalance,
        electronicBalanceAccountId = electronicBalanceAccountId,
        electronicBalanceCategory = electronicBalanceCategory,
        productName = _normalizeElectronicProductName(productName, isElectronicBalance, electronicBalanceCategory),
        metadata = metadata ?? SyncMetadata.initial();

  static String _normalizeElectronicProductName(String value, bool electronic, String? category) {
    final name = value.trim();
    final type = category?.trim() ?? '';
    if (!electronic || type.isEmpty || name.isEmpty) return name;
    if (name == type || name.endsWith(' · $type')) return name;
    return '$name · $type';
  }

  Map<String, dynamic> toMap() => {'id': id, 'productId': productId, 'productName': productName, 'unit': unit, 'brand': brand, 'barcode': barcode, 'cost': cost, 'unitPrice': unitPrice, 'quantity': quantity, 'lineSubtotal': lineSubtotal, 'discount': discount, 'lineTotal': lineTotal, 'imageData': imageData, 'isElectronicBalance': isElectronicBalance, 'hasGroupPricing': hasGroupPricing, 'electronicBalanceAccountId': electronicBalanceAccountId, 'electronicBalanceCategory': electronicBalanceCategory, 'metadata': metadata.toMap()};

  factory SaleItemRecord.fromMap(Map<String, dynamic> map) => SaleItemRecord(id: map['id']?.toString(), productId: map['productId']?.toString() ?? '', productName: map['productName']?.toString() ?? '', unit: map['unit']?.toString() ?? '', brand: map['brand']?.toString() ?? '', barcode: map['barcode']?.toString() ?? '', cost: _double(map['cost']), unitPrice: _double(map['unitPrice']), quantity: _int(map['quantity']), lineSubtotal: _double(map['lineSubtotal']), discount: _double(map['discount']), lineTotal: _double(map['lineTotal']), imageData: map['imageData']?.toString() ?? '', isElectronicBalance: _bool(map['isElectronicBalance']), hasGroupPricing: _bool(map['hasGroupPricing']), electronicBalanceAccountId: map['electronicBalanceAccountId']?.toString(), electronicBalanceCategory: map['electronicBalanceCategory']?.toString(), metadata: _metadata(map['metadata']));

  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
  static bool _bool(dynamic v) => v is bool ? v : ['true', '1', 'si', 'sí'].contains(v?.toString().toLowerCase());
  static SyncMetadata _metadata(dynamic v) => v is Map ? SyncMetadata.fromMap(Map<String, dynamic>.from(v)) : SyncMetadata.initial();
}

class SaleRecord implements SyncableEntity {
  static DateTime? _creationDateOverride;

  static void setCreationDateOverride(DateTime date) {
    _creationDateOverride = date;
  }

  static void clearCreationDateOverride() {
    _creationDateOverride = null;
  }

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
  SaleStatus status;
  List<SaleOperationRecord> operations;
  @override SyncMetadata metadata;

  SaleRecord({required this.id, required this.ticketNumber, required this.createdAt, required this.clientId, required this.clientName, required this.paymentMethod, required List<SaleItemRecord> items, required this.subtotal, required this.discountPercent, required this.discountAmount, required this.cardFeeAmount, required this.total, required this.received, required this.change, this.status = SaleStatus.completed, List<SaleOperationRecord> operations = const [], SyncMetadata? metadata}) : items = List.unmodifiable(items), operations = List.unmodifiable(operations), metadata = metadata ?? SyncMetadata(createdAt: createdAt.toUtc(), updatedAt: createdAt.toUtc()) {
    final override = _creationDateOverride;
    if (override != null) {
      final original = createdAt;
      createdAt = DateTime(override.year, override.month, override.day, original.hour, original.minute, original.second, original.millisecond, original.microsecond);
      if (metadata == null) {
        this.metadata = SyncMetadata(createdAt: createdAt.toUtc(), updatedAt: createdAt.toUtc());
      }
    }
  }

  bool get isCompleted => status == SaleStatus.completed;
  bool get isAnnulled => status == SaleStatus.annulled;
  bool get canOperateToday {
    final now = DateTime.now();
    return createdAt.year == now.year && createdAt.month == now.month && createdAt.day == now.day;
  }
  double get operationDelta => operations.fold(0, (sum, operation) => sum + operation.amountDelta);
  double get effectiveTotal => isAnnulled ? 0 : (total + operationDelta).clamp(0, double.infinity).toDouble();
  double get effectiveCollected => paymentMethod == 'Fiado' ? (received + operationDelta).clamp(0, effectiveTotal).toDouble() : effectiveTotal;
  double get effectiveProfit {
    if (isAnnulled) return 0;
    var profit = items.fold<double>(0, (sum, item) => sum + (item.unitPrice * item.quantity - item.discount - item.cost * item.quantity));
    for (final operation in operations) {
      profit -= operation.itemsOut.fold<double>(0, (sum, item) => sum + (item.unitPrice * item.quantity - item.discount - item.cost * item.quantity));
      profit += operation.itemsIn.fold<double>(0, (sum, item) => sum + (item.unitPrice * item.quantity - item.discount - item.cost * item.quantity));
    }
    return profit;
  }

  void updateCreatedAt(DateTime value) {
    createdAt = value;
    metadata = metadata.touch();
  }

  SaleRecord copyWith({String? id, String? ticketNumber, DateTime? createdAt, String? clientId, String? clientName, String? paymentMethod, List<SaleItemRecord>? items, double? subtotal, double? discountPercent, double? discountAmount, double? cardFeeAmount, double? total, double? received, double? change, SaleStatus? status, List<SaleOperationRecord>? operations, SyncMetadata? metadata, bool touchMetadata = false}) => SaleRecord(id: id ?? this.id, ticketNumber: ticketNumber ?? this.ticketNumber, createdAt: createdAt ?? this.createdAt, clientId: clientId ?? this.clientId, clientName: clientName ?? this.clientName, paymentMethod: paymentMethod ?? this.paymentMethod, items: items ?? this.items, subtotal: subtotal ?? this.subtotal, discountPercent: discountPercent ?? this.discountPercent, discountAmount: discountAmount ?? this.discountAmount, cardFeeAmount: cardFeeAmount ?? this.cardFeeAmount, total: total ?? this.total, received: received ?? this.received, change: change ?? this.change, status: status ?? this.status, operations: operations ?? this.operations, metadata: metadata ?? (touchMetadata ? this.metadata.touch() : this.metadata));

  Map<String, dynamic> toMap() => {'id': id, 'ticketNumber': ticketNumber, 'createdAt': createdAt.toIso8601String(), 'clientId': clientId, 'clientName': clientName, 'paymentMethod': paymentMethod, 'items': items.map((item) => item.toMap()).toList(), 'subtotal': subtotal, 'discountPercent': discountPercent, 'discountAmount': discountAmount, 'cardFeeAmount': cardFeeAmount, 'total': total, 'received': received, 'change': change, 'status': status.name, 'operations': operations.map((operation) => operation.toMap()).toList(growable: false), 'metadata': metadata.toMap()};

  factory SaleRecord.fromMap(Map<String, dynamic> map) => SaleRecord(id: map['id']?.toString() ?? IdGenerator.newId(), ticketNumber: map['ticketNumber']?.toString() ?? '', createdAt: _date(map['createdAt']), clientId: map['clientId']?.toString(), clientName: map['clientName']?.toString() ?? '', paymentMethod: map['paymentMethod']?.toString() ?? '', items: _items(map['items']), subtotal: _double(map['subtotal']), discountPercent: _double(map['discountPercent']), discountAmount: _double(map['discountAmount']), cardFeeAmount: _double(map['cardFeeAmount']), total: _double(map['total']), received: _double(map['received']), change: _double(map['change']), status: map['status']?.toString() == SaleStatus.annulled.name ? SaleStatus.annulled : SaleStatus.completed, operations: _operations(map['operations']), metadata: _metadata(map['metadata']));

  SaleTicketData toTicketData() {
    final date = '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
    final hour = createdAt.hour % 12 == 0 ? 12 : createdAt.hour % 12;
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    final time = '${hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')} $period';
    return SaleTicketData(ticketNumber: ticketNumber, date: date, time: time, client: clientName, status: isAnnulled ? 'ANULADA' : 'COMPLETADA', operations: operations.map((operation) => SaleTicketOperation(label: operation.label, amountDelta: operation.amountDelta, details: _ticketOperationDetails(operation))).toList(growable: false), items: items.map((item) => SaleTicketItem(quantity: item.quantity, description: item.productName, brand: item.brand, unit: item.isElectronicBalance ? '' : item.unit, unitPrice: item.hasGroupPricing ? item.lineTotal : item.unitPrice, discount: item.discount, total: item.lineTotal)).toList(growable: false), subtotal: subtotal, discount: discountAmount, cardFee: cardFeeAmount, total: effectiveTotal, paymentMethod: paymentMethod, received: effectiveCollected, change: change);
  }

  static String _ticketOperationDetails(SaleOperationRecord operation) {
    final out = operation.itemsOut.map((item) => 'SALE: ${item.productName} x${item.quantity} ${_money(item.lineTotal)}').join(' | ');
    final incoming = operation.itemsIn.map((item) => 'ENTRA: ${item.productName} x${item.quantity} ${_money(item.lineTotal)}').join(' | ');
    final amount = operation.amountDelta.abs() <= 0.005 ? 'SIN DIFERENCIA' : operation.amountDelta < 0 ? 'DEVOLVER: ${_money(operation.amountDelta.abs())}' : 'COBRAR: ${_money(operation.amountDelta)}';
    return [out, incoming, amount].where((value) => value.isNotEmpty).join(' · ');
  }

  static String _money(double value) => '\$${value.toStringAsFixed(2)}';
  static List<SaleOperationRecord> _operations(dynamic v) => v is Iterable ? v.whereType<Map>().map((i) => SaleOperationRecord.fromMap(Map<String, dynamic>.from(i))).toList() : const [];
  static List<SaleItemRecord> _items(dynamic v) => v is Iterable ? v.whereType<Map>().map((i) => SaleItemRecord.fromMap(Map<String, dynamic>.from(i))).toList() : const [];
  static DateTime _date(dynamic v) => v is DateTime ? v : DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
  static double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  static SyncMetadata _metadata(dynamic v) => v is Map ? SyncMetadata.fromMap(Map<String, dynamic>.from(v)) : SyncMetadata.initial();
}
