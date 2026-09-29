import 'package:stellar_pos/core/cloud/cloud_collection.dart';
import 'package:stellar_pos/core/cloud/cloud_identity_store.dart';
import 'package:stellar_pos/core/cloud/cloud_repository.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_coordinator.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_scope.dart';
import 'package:stellar_pos/core/cloud/firestore_data_source.dart';
import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/electronic_balance.dart';

/// Electronic-balance accounts repository with local-first persistence and
/// optional cloud synchronization.
class ElectronicBalanceAccountRepository
    implements Repository<ElectronicBalanceAccount> {
  final HiveDataSource<ElectronicBalanceAccount> _local =
      HiveDataSource<ElectronicBalanceAccount>(
    boxName: StorageBoxes.electronicBalanceAccounts,
    fromMap: ElectronicBalanceAccount.fromMap,
  );
  final CloudIdentityStore _identityStore;
  final CloudSyncCoordinator _syncCoordinator;

  CloudRepository<ElectronicBalanceAccount>? _cloud;
  String? _cloudStoreId;
  String? _cloudDeviceId;

  ElectronicBalanceAccountRepository({
    CloudIdentityStore? identityStore,
    CloudSyncCoordinator? syncCoordinator,
  })  : _identityStore = identityStore ?? CloudIdentityStore(),
        _syncCoordinator = syncCoordinator ?? CloudSyncCoordinator.instance;

  @override
  Future<List<ElectronicBalanceAccount>> getAll() async {
    await _trySync();
    return _local.getAll();
  }

  @override
  Future<ElectronicBalanceAccount?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(ElectronicBalanceAccount entity) async {
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
    CloudRepository<ElectronicBalanceAccount>? existing,
  ]) async {
    final cloud = existing ?? await _getCloudRepository();
    if (cloud == null) return;

    try {
      final storeId = await _identityStore.getStoreId();
      if (storeId == null || storeId.isEmpty) return;

      await _syncCoordinator.run(
        key: '$storeId:${CloudCollection.electronicBalanceAccounts}',
        operation: cloud.sync,
      );
    } catch (_) {
      // Keep electronic-balance management available while Firebase is
      // unavailable or while the cloud tenant/security configuration is not
      // ready.
    }
  }

  Future<CloudRepository<ElectronicBalanceAccount>?>
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
    _cloud = CloudRepository<ElectronicBalanceAccount>(
      local: _local,
      cloud: FirestoreDataSource<ElectronicBalanceAccount>(
        storeId: storeId,
        collectionName: CloudCollection.electronicBalanceAccounts,
        fromMap: ElectronicBalanceAccount.fromMap,
      ),
      scope: CloudSyncScope(
        storeId: storeId,
        deviceId: deviceId,
      ),
      collection: CloudCollection.electronicBalanceAccounts,
      fromMap: ElectronicBalanceAccount.fromMap,
    );
    return _cloud;
  }
}
