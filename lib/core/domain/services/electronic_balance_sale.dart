class ElectronicBalanceSale {
  final double amount;
  final int quantity;
  final String category;
  final String description;

  const ElectronicBalanceSale({
    required this.amount,
    required this.quantity,
    required this.category,
    this.description = '',
  });
}
