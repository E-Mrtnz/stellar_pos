import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';

/// Local repository for electronic-balance transactions.
class ElectronicBalanceTransactionRepository
    extends HiveRepository<ElectronicBalanceTransaction> {
  ElectronicBalanceTransactionRepository()
      : super(
          HiveDataSource<ElectronicBalanceTransaction>(
            boxName: StorageBoxes.electronicBalanceTransactions,
            fromMap: ElectronicBalanceTransaction.fromMap,
          ),
        );
}
