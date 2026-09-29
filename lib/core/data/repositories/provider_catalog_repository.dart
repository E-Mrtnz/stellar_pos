import 'package:stellar_pos/core/cloud/cloud_collection.dart';
import 'package:stellar_pos/core/cloud/cloud_identity_store.dart';
import 'package:stellar_pos/core/cloud/cloud_repository.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_coordinator.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_scope.dart';
import 'package:stellar_pos/core/cloud/firestore_data_source.dart';
import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/provider_catalog_state.dart';

/// Provider-catalog repository with local-first persistence and optional cloud
/// synchronization.
class ProviderCatalogRepository implements Repository<ProviderCatalogState> {
  final HiveDataSource<ProviderCatalogState> _local =
      HiveDataSource<ProviderCatalogState>(
    boxName: StorageBoxes.providerCatalog,
    fromMap: ProviderCatalogState.fromMap,
  );
  final CloudIdentityStore _identityStore;
  final CloudSyncCoordinator _syncCoordinator;

  CloudRepository<ProviderCatalogState>? _cloud;
  String? _cloudStoreId;
  String? _cloudDeviceId;

  ProviderCatalogRepository({
    CloudIdentityStore? identityStore,
    CloudSyncCoordinator? syncCoordinator,
  })  : _identityStore = identityStore ?? CloudIdentityStore(),
        _syncCoordinator = syncCoordinator ?? CloudSyncCoordinator.instance;

  @override
  Future<List<ProviderCatalogState>> getAll() async {
    await _trySync();
    return _local.getAll();
  }

  @override
  Future<ProviderCatalogState?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(ProviderCatalogState entity) async {
    final cloud = await _getCloudRepository();
    if (cloud == null) {
      await _local.save(entity);
      return;
    }

    await cloud.save(entity);
    await _trySync(cloud);
  }

  @override
  Future<void> delete(String id) async {
    final cloud = await _getCloudRepository();
    if (cloud == null) {
      await _local.delete(id);
      return;
    }

    await cloud.delete(id);
    await _trySync(cloud);
  }

  Future<void> sync() => _trySync();

  Future<void> _trySync([
    CloudRepository<ProviderCatalogState>? existing,
  ]) async {
    final cloud = existing ?? await _getCloudRepository();
    if (cloud == null) return;

    try {
      final storeId = await _identityStore.getStoreId();
      if (storeId == null || storeId.isEmpty) return;

      await _syncCoordinator.run(
        key: '$storeId:${CloudCollection.providerCatalog}',
        operation: cloud.sync,
      );
    } catch (_) {
      // Keep provider catalog management available while Firebase is
      // unavailable or while the cloud tenant/security configuration is not
      // ready.
    }
  }

  Future<CloudRepository<ProviderCatalogState>?>
      _getCloudRepository() async {
    final storeId = await _identityStore.getStoreId();
    if (storeId == null || storeId.isEmpty) return null;

    final deviceId = await _identityStore.getOrCreateDeviceId();
    if (_cloud != null &&
        _cloudStoreId == storeId &&
        _cloudDeviceId == deviceId) {
      return _cloud;
    }

    _cloudStoreId = storeId;
    _cloudDeviceId = deviceId;
    _cloud = CloudRepository<ProviderCatalogState>(
      local: _local,
      cloud: FirestoreDataSource<ProviderCatalogState>(
        storeId: storeId,
        collectionName: CloudCollection.providerCatalog,
        fromMap: ProviderCatalogState.fromMap,
      ),
      scope: CloudSyncScope(
        storeId: storeId,
        deviceId: deviceId,
      ),
      collection: CloudCollection.providerCatalog,
      fromMap: ProviderCatalogState.fromMap,
    );
    return _cloud;
  }
}
