import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/repositories/hive_repository.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/models/provider_person.dart';

/// Local repository for provider delivery routes.
class ProviderRouteRepository extends HiveRepository<ProviderRoute> {
  ProviderRouteRepository()
      : super(
          HiveDataSource<ProviderRoute>(
            boxName: StorageBoxes.providerRoutes,
            fromMap: ProviderRoute.fromMap,
          ),
        );
}
