import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/purchase.dart';

/// Local Hive repository for PurchaseRecord.
///
/// Cloud synchronization is intentionally not part of the repository layer.
/// It will be reintroduced through a new, explicit cloud architecture later.
class PurchaseRepository implements Repository<PurchaseRecord> {
  final HiveDataSource<PurchaseRecord> _local = HiveDataSource<PurchaseRecord>(
    boxName: StorageBoxes.purchases,
    fromMap: PurchaseRecord.fromMap,
  );

  @override
  Future<List<PurchaseRecord>> getAll() => _local.getAll();

  @override
  Future<PurchaseRecord?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(PurchaseRecord entity) => _local.save(entity);

  @override
  Future<void> delete(String id) => _local.delete(id);
}
