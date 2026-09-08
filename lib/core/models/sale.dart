import 'package:stellar_pos/core/models/sale_ticket.dart';

class SaleItemRecord {
  String productId;
  String productName;
  String unit;
  String barcode;
  double cost;
  double unitPrice;
  int quantity;
  double lineSubtotal;
  double discount;
  double lineTotal;
  String imageData;
  bool isElectronicBalance;
  String? electronicBalanceAccountId;
  String? electronicBalanceCategory;

  SaleItemRecord({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.barcode,
    required this.cost,
    required this.unitPrice,
    required this.quantity,
    required this.lineSubtotal,
    required this.discount,
    required this.lineTotal,
    this.imageData = '',
    this.isElectronicBalance = false,
    this.electronicBalanceAccountId,
    this.electronicBalanceCategory,
  });

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'unit': unit,
    'barcode': barcode,
    'cost': cost,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'lineSubtotal': lineSubtotal,
    'discount': discount,
    'lineTotal': lineTotal,
    'imageData': imageData,
    'isElectronicBalance': isElectronicBalance,
    'electronicBalanceAccountId': electronicBalanceAccountId,
    'electronicBalanceCategory': electronicBalanceCategory,
  };
}

class SaleRecord {
  String id;
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

  SaleRecord({
    required this.id,
    required this.ticketNumber,
    required this.createdAt,
    required this.clientId,
    required this.clientName,
    required this.paymentMethod,
    required this.items,
    required this.subtotal,
    required this.discountPercent,
    required this.discountAmount,
    required this.cardFeeAmount,
    required this.total,
    required this.received,
    required this.change,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'ticketNumber': ticketNumber,
    'createdAt': createdAt.toIso8601String(),
    'clientId': clientId,
    'clientName': clientName,
    'paymentMethod': paymentMethod,
    'items': items.map((item) => item.toMap()).toList(),
    'subtotal': subtotal,
    'discountPercent': discountPercent,
    'discountAmount': discountAmount,
    'cardFeeAmount': cardFeeAmount,
    'total': total,
    'received': received,
    'change': change,
  };

  SaleTicketData toTicketData() {
    final date = '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
    final hour = createdAt.hour % 12 == 0 ? 12 : createdAt.hour % 12;
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    final time = '${hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')} $period';
    return SaleTicketData(
      ticketNumber: ticketNumber,
      date: date,
      time: time,
      client: clientName,
      items: items.map((item) => SaleTicketItem(
        quantity: item.quantity,
        description: item.productName,
        unitPrice: item.unitPrice,
        discount: item.discount,
        total: item.lineTotal,
      )).toList(growable: false),
      subtotal: subtotal,
      discount: discountAmount,
      cardFee: cardFeeAmount,
      total: total,
      paymentMethod: paymentMethod,
      received: received,
      change: change,
    );
  }
}
