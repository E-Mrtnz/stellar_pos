class SaleTicketItem {
  final int quantity;
  final String description;
  final String brand;
  final String unit;
  final double unitPrice;
  final double discount;
  final double total;

  const SaleTicketItem({required this.quantity, required this.description, this.brand = '', this.unit = '', required this.unitPrice, required this.discount, required this.total});
}

class SaleTicketOperation {
  final String label;
  final double amountDelta;
  final String details;

  const SaleTicketOperation({required this.label, required this.amountDelta, required this.details});
}

class SaleTicketData {
  final String ticketNumber;
  final String date;
  final String time;
  final String client;
  final String status;
  final List<SaleTicketOperation> operations;
  final List<SaleTicketItem> items;
  final double subtotal;
  final double discount;
  final double cardFee;
  final double total;
  final String paymentMethod;
  final double received;
  final double change;

  const SaleTicketData({required this.ticketNumber, required this.date, required this.time, required this.client, this.status = 'COMPLETADA', this.operations = const [], required this.items, required this.subtotal, required this.discount, this.cardFee = 0, required this.total, required this.paymentMethod, required this.received, required this.change});
}
