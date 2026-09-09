/// Input data for one electronic-balance sale line.
///
/// This is an application/domain DTO, not a presentation Provider model.
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
