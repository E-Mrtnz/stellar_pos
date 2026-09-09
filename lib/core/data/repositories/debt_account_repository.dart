import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/models/debt.dart';

/// Local repository for debt account summaries.
class DebtAccountRepository extends HiveRepository<DebtAccount> {
  DebtAccountRepository()
      : super(
          HiveDataSource<DebtAccount>(
            boxName: StorageBoxes.debtAccounts,
            fromMap: DebtAccount.fromMap,
          ),
        );
}
