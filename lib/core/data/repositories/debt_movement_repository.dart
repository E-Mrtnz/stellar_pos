import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/debt.dart';

/// Local Hive repository for DebtMovement.
///
/// Cloud synchronization is intentionally not part of the repository layer.
/// It will be reintroduced through a new, explicit cloud architecture later.
class DebtMovementRepository implements Repository<DebtMovement> {
  final HiveDataSource<DebtMovement> _local = HiveDataSource<DebtMovement>(
    boxName: StorageBoxes.debtMovements,
    fromMap: DebtMovement.fromMap,
  );

  @override
  Future<List<DebtMovement>> getAll() => _local.getAll();

  @override
  Future<DebtMovement?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(DebtMovement entity) => _local.save(entity);

  @override
  Future<void> delete(String id) => _local.delete(id);
}
