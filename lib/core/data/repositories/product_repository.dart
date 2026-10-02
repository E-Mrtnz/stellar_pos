import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/product.dart';

/// Local Hive repository for Product.
///
/// Cloud synchronization is intentionally not part of the repository layer.
/// It will be reintroduced through a new, explicit cloud architecture later.
class ProductRepository implements Repository<Product> {
  final HiveDataSource<Product> _local = HiveDataSource<Product>(
    boxName: StorageBoxes.products,
    fromMap: Product.fromMap,
  );

  @override
  Future<List<Product>> getAll() => _local.getAll();

  @override
  Future<Product?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(Product entity) => _local.save(entity);

  @override
  Future<void> delete(String id) => _local.delete(id);
}
