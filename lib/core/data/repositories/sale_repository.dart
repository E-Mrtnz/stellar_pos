import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/models/sale.dart';

/// Local repository for completed sales.
class SaleRepository extends HiveRepository<SaleRecord> {
  SaleRepository()
      : super(
          HiveDataSource<SaleRecord>(
            boxName: StorageBoxes.sales,
            fromMap: SaleRecord.fromMap,
          ),
        );
}
