import 'dart:async';

import 'package:stellar_pos/core/cloud/cloud_collection.dart';
import 'package:stellar_pos/core/cloud/cloud_identity_store.dart';
import 'package:stellar_pos/core/cloud/cloud_repository.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_coordinator.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_scope.dart';
import 'package:stellar_pos/core/cloud/firestore_data_source.dart';
import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/client.dart';

/// Client repository with local-first persistence and optional cloud sync.
///
/// The presentation layer continues to depend only on [Repository]. Hive
/// remains the local source of truth while Firestore is used only when an
/// explicit store identity has been configured.
class ClientRepository implements Repository<Client> {
  final HiveDataSource<Client> _local = HiveDataSource<Client>(
    boxName: StorageBoxes.clients,
    fromMap: Client.fromMap,
  );
  final CloudIdentityStore _identityStore;
  final CloudSyncCoordinator _syncCoordinator;

  CloudRepository<Client>? _cloud;
  String? _cloudStoreId;
  String? _cloudDeviceId;

  ClientRepository({
    CloudIdentityStore? identityStore,
    CloudSyncCoordinator? syncCoordinator,
  })  : _identityStore = identityStore ?? CloudIdentityStore(),
        _syncCoordinator = syncCoordinator ?? CloudSyncCoordinator.instance;

  @override
  Future<List<Client>> getAll() async {
    // Local-first: never block the UI waiting for Firestore.
    unawaited(_trySync());
    return _local.getAll();
  }

  @override
  Future<Client?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(Client entity) async {
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

  /// Performs a best-effort synchronization for the configured store.
  Future<void> sync() => _trySync();

  Future<void> _trySync([CloudRepository<Client>? existing]) async {
    final cloud = existing ?? await _getCloudRepository();
    if (cloud == null) return;

    try {
      final storeId = await _identityStore.getStoreId();
      if (storeId == null || storeId.isEmpty) return;

      await _syncCoordinator.run(
        key: '$storeId:${CloudCollection.clients}',
        operation: cloud.sync,
      );
    } catch (_) {
      // Local POS operation remains available while Firebase is unavailable
      // or while the security/tenant configuration is not ready.
    }
  }

  Future<CloudRepository<Client>?> _getCloudRepository() async {
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
    _cloud = CloudRepository<Client>(
      local: _local,
      cloud: FirestoreDataSource<Client>(
        storeId: storeId,
        collectionName: CloudCollection.clients,
        fromMap: Client.fromMap,
      ),
      scope: CloudSyncScope(
        storeId: storeId,
        deviceId: deviceId,
      ),
      collection: CloudCollection.clients,
      fromMap: Client.fromMap,
    );
    return _cloud;
  }
}
