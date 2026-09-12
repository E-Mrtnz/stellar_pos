import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/models/client_group.dart';

class ClientGroupRepository extends HiveRepository<ClientGroup> {
  ClientGroupRepository()
      : super(
          HiveDataSource<ClientGroup>(
            boxName: StorageBoxes.clientGroups,
            fromMap: ClientGroup.fromMap,
          ),
        );
}
