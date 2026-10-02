import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/provider_person.dart';

/// Local Hive repository for ProviderRoute.
///
/// Cloud synchronization is intentionally not part of the repository layer.
/// It will be reintroduced through a new, explicit cloud architecture later.
class ProviderRouteRepository implements Repository<ProviderRoute> {
  final HiveDataSource<ProviderRoute> _local = HiveDataSource<ProviderRoute>(
    boxName: StorageBoxes.providerRoutes,
    fromMap: ProviderRoute.fromMap,
  );

  @override
  Future<List<ProviderRoute>> getAll() => _local.getAll();

  @override
  Future<ProviderRoute?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(ProviderRoute entity) => _local.save(entity);

  @override
  Future<void> delete(String id) => _local.delete(id);
}
