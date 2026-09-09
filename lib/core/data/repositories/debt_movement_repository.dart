import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/models/debt.dart';

/// Local repository for debt movements and payments.
class DebtMovementRepository extends HiveRepository<DebtMovement> {
  DebtMovementRepository()
      : super(
          HiveDataSource<DebtMovement>(
            boxName: StorageBoxes.debtMovements,
            fromMap: DebtMovement.fromMap,
          ),
        );
}
