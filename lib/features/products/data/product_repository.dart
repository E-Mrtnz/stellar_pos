import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_box_names.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';

/// Local product repository.
///
/// The feature depends on the domain [Repository] contract while this class
/// selects Hive as its current local implementation.
class ProductRepository implements Repository<Product> {
  ProductRepository()
      : _repository = HiveRepository<Product>(
          HiveDataSource<Product>(
            boxName: StorageBoxNames.products,
            fromMap: Product.fromMap,
          ),
        );

  final Repository<Product> _repository;

  @override
  Future<List<Product>> getAll() => _repository.getAll();

  @override
  Future<Product?> getById(String id) => _repository.getById(id);

  @override
  Future<void> save(Product entity) => _repository.save(entity);

  @override
  Future<void> delete(String id) => _repository.delete(id);
}
