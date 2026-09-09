import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/models/product.dart';

/// Local repository for products.
///
/// The feature depends on the [Product] repository contract rather than Hive
/// directly. Replacing Hive later therefore does not require changing the
/// presentation layer.
class ProductRepository extends HiveRepository<Product> {
  ProductRepository()
      : super(
          HiveDataSource<Product>(
            boxName: StorageBoxes.products,
            fromMap: Product.fromMap,
          ),
        );
}
