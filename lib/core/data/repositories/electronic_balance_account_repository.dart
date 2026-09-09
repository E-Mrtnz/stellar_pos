import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';

/// Local repository for electronic-balance accounts.
class ElectronicBalanceAccountRepository
    extends HiveRepository<ElectronicBalanceAccount> {
  ElectronicBalanceAccountRepository()
      : super(
          HiveDataSource<ElectronicBalanceAccount>(
            boxName: StorageBoxes.electronicBalanceAccounts,
            fromMap: ElectronicBalanceAccount.fromMap,
          ),
        );
}
