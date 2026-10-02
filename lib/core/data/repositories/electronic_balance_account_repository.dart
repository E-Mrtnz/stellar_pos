import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';

/// Local Hive repository for ElectronicBalanceAccount.
///
/// Cloud synchronization is intentionally not part of the repository layer.
/// It will be reintroduced through a new, explicit cloud architecture later.
class ElectronicBalanceAccountRepository implements Repository<ElectronicBalanceAccount> {
  final HiveDataSource<ElectronicBalanceAccount> _local = HiveDataSource<ElectronicBalanceAccount>(
    boxName: StorageBoxes.electronicBalanceAccounts,
    fromMap: ElectronicBalanceAccount.fromMap,
  );

  @override
  Future<List<ElectronicBalanceAccount>> getAll() => _local.getAll();

  @override
  Future<ElectronicBalanceAccount?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(ElectronicBalanceAccount entity) => _local.save(entity);

  @override
  Future<void> delete(String id) => _local.delete(id);
}
