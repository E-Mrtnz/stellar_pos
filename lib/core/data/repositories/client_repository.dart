import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/models/client.dart';

/// Local repository for clients.
class ClientRepository extends HiveRepository<Client> {
  ClientRepository()
      : super(
          HiveDataSource<Client>(
            boxName: StorageBoxes.clients,
            fromMap: Client.fromMap,
          ),
        );
}
