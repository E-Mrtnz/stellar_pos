import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/sale.dart';

/// Local Hive repository for SaleRecord.
///
/// Cloud synchronization is intentionally not part of the repository layer.
/// It will be reintroduced through a new, explicit cloud architecture later.
class SaleRepository implements Repository<SaleRecord> {
  final HiveDataSource<SaleRecord> _local = HiveDataSource<SaleRecord>(
    boxName: StorageBoxes.sales,
    fromMap: SaleRecord.fromMap,
  );

  @override
  Future<List<SaleRecord>> getAll() => _local.getAll();

  @override
  Future<SaleRecord?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(SaleRecord entity) => _local.save(entity);

  @override
  Future<void> delete(String id) => _local.delete(id);
}
