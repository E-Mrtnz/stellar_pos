import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/client_group.dart';

/// Local Hive repository for ClientGroup.
///
/// Cloud synchronization is intentionally not part of the repository layer.
/// It will be reintroduced through a new, explicit cloud architecture later.
class ClientGroupRepository implements Repository<ClientGroup> {
  final HiveDataSource<ClientGroup> _local = HiveDataSource<ClientGroup>(
    boxName: StorageBoxes.clientGroups,
    fromMap: ClientGroup.fromMap,
  );

  @override
  Future<List<ClientGroup>> getAll() => _local.getAll();

  @override
  Future<ClientGroup?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(ClientGroup entity) => _local.save(entity);

  @override
  Future<void> delete(String id) => _local.delete(id);
}
