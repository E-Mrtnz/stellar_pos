import 'dart:developer' as developer;

import 'dart:async';

import 'package:stellar_pos/core/cloud/cloud_collection.dart';
import 'package:stellar_pos/core/cloud/cloud_identity_store.dart';
import 'package:stellar_pos/core/cloud/cloud_repository.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_coordinator.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_scope.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_engine.dart';
import 'package:stellar_pos/core/cloud/firestore_data_source.dart';
import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/purchase.dart';

/// Purchase repository with local-first persistence and optional cloud sync.
///
/// Purchase records are stored locally in Hive for normal POS operation. When
/// a store has explicitly been assigned to the installation, the same records
/// are synchronized through the cloud boundary without exposing Firestore to
/// the presentation layer.
class PurchaseRepository implements Repository<PurchaseRecord> {
  final HiveDataSource<PurchaseRecord> _local = HiveDataSource<PurchaseRecord>(
    boxName: StorageBoxes.purchases,
    fromMap: PurchaseRecord.fromMap,
  );
  final CloudIdentityStore _identityStore;
  final CloudSyncCoordinator _syncCoordinator;

  CloudRepository<PurchaseRecord>? _cloud;
  String? _cloudStoreId;
  String? _cloudDeviceId;

  PurchaseRepository({
    CloudIdentityStore? identityStore,
    CloudSyncCoordinator? syncCoordinator,
  })  : _identityStore = identityStore ?? CloudIdentityStore(),
        _syncCoordinator = syncCoordinator ?? CloudSyncCoordinator.instance;

  @override
  Future<List<PurchaseRecord>> getAll() async {
    // Local-first: never block the UI waiting for Firestore.
    unawaited(_trySync());
    return _local.getAll();
  }

  @override
  Future<PurchaseRecord?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(PurchaseRecord entity) async {
    final cloud = await _getCloudRepository();
    if (cloud == null) {
      await _local.save(entity);
      return;
    }

    await cloud.save(entity);
    unawaited(_trySync(cloud));
  }

  @override
  Future<void> delete(String id) async {
    final cloud = await _getCloudRepository();
    if (cloud == null) {
      await _local.delete(id);
      return;
    }

    await cloud.delete(id);
    unawaited(_trySync(cloud));
  }

  Future<CloudSyncResult?> sync() => _trySync();

  Future<CloudSyncResult?> _trySync([CloudRepository<PurchaseRecord>? existing]) async {
    final cloud = existing ?? await _getCloudRepository();
    if (cloud == null) return null;

    try {
      final storeId = await _identityStore.getStoreId();
      if (storeId == null || storeId.isEmpty) return null;

      return await _syncCoordinator.run<CloudSyncResult>(
        key: '$storeId:${CloudCollection.purchases}',
        operation: cloud.sync,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Falló la sincronización de Firestore.',
        name: 'STELLAR_POS.cloud_sync',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<CloudRepository<PurchaseRecord>?> _getCloudRepository() async {
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
    _cloud = CloudRepository<PurchaseRecord>(
      local: _local,
      cloud: FirestoreDataSource<PurchaseRecord>(
        storeId: storeId,
        collectionName: CloudCollection.purchases,
        fromMap: PurchaseRecord.fromMap,
      ),
      scope: CloudSyncScope(
        storeId: storeId,
        deviceId: deviceId,
      ),
      collection: CloudCollection.purchases,
      fromMap: PurchaseRecord.fromMap,
    );
    return _cloud;
  }
}
