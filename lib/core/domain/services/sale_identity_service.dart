import 'package:stellar_pos/core/utils/id_generator.dart';

/// Generates stable identifiers for sales.
///
/// The public ticket number remains a sequential business value, while the
/// entity id is independent from time and presentation. This makes the sale
/// safe to persist and synchronize later.
class SaleIdentityService {
  const SaleIdentityService();

  String newSaleId() => IdGenerator.newId();
}
