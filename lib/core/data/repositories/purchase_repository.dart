import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/models/purchase.dart';

/// Local repository for purchase records.
class PurchaseRepository extends HiveRepository<PurchaseRecord> {
  PurchaseRepository()
      : super(
          HiveDataSource<PurchaseRecord>(
            boxName: StorageBoxes.purchases,
            fromMap: PurchaseRecord.fromMap,
          ),
        );
}
