import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';

/// Local Hive repository for ElectronicBalanceTransaction.
///
/// Cloud synchronization is intentionally not part of the repository layer.
/// It will be reintroduced through a new, explicit cloud architecture later.
class ElectronicBalanceTransactionRepository implements Repository<ElectronicBalanceTransaction> {
  final HiveDataSource<ElectronicBalanceTransaction> _local = HiveDataSource<ElectronicBalanceTransaction>(
    boxName: StorageBoxes.electronicBalanceTransactions,
    fromMap: ElectronicBalanceTransaction.fromMap,
  );

  @override
  Future<List<ElectronicBalanceTransaction>> getAll() => _local.getAll();

  @override
  Future<ElectronicBalanceTransaction?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(ElectronicBalanceTransaction entity) => _local.save(entity);

  @override
  Future<void> delete(String id) => _local.delete(id);
}
