import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/models/provider_catalog_state.dart';

/// Local repository for provider catalog configuration.
class ProviderCatalogRepository extends HiveRepository<ProviderCatalogState> {
  ProviderCatalogRepository()
      : super(
          HiveDataSource<ProviderCatalogState>(
            boxName: StorageBoxes.providerCatalog,
            fromMap: ProviderCatalogState.fromMap,
          ),
        );
}
