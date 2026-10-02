import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/provider_catalog_state.dart';

/// Local Hive repository for ProviderCatalogState.
///
/// Cloud synchronization is intentionally not part of the repository layer.
/// It will be reintroduced through a new, explicit cloud architecture later.
class ProviderCatalogRepository implements Repository<ProviderCatalogState> {
  final HiveDataSource<ProviderCatalogState> _local = HiveDataSource<ProviderCatalogState>(
    boxName: StorageBoxes.providerCatalog,
    fromMap: ProviderCatalogState.fromMap,
  );

  @override
  Future<List<ProviderCatalogState>> getAll() => _local.getAll();

  @override
  Future<ProviderCatalogState?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(ProviderCatalogState entity) => _local.save(entity);

  @override
  Future<void> delete(String id) => _local.delete(id);
}
