import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/client.dart';

/// Local Hive repository for Client.
///
/// Cloud synchronization is intentionally not part of the repository layer.
/// It will be reintroduced through a new, explicit cloud architecture later.
class ClientRepository implements Repository<Client> {
  final HiveDataSource<Client> _local = HiveDataSource<Client>(
    boxName: StorageBoxes.clients,
    fromMap: Client.fromMap,
  );

  @override
  Future<List<Client>> getAll() => _local.getAll();

  @override
  Future<Client?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(Client entity) => _local.save(entity);

  @override
  Future<void> delete(String id) => _local.delete(id);
}
