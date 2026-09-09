import 'package:stellar_pos/core/models/sale.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

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
