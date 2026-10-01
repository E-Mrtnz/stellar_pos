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
import 'package:stellar_pos/core/models/sale.dart';

/// Sales repository with local-first persistence and optional cloud sync.
///
/// Completed sales are kept locally in Hive for immediate POS operation. Once
/// a store identity is configured, the same records are synchronized through
/// the cloud abstraction without exposing Firebase to the sales UI.
class SaleRepository implements Repository<SaleRecord> {
  final HiveDataSource<SaleRecord> _local = HiveDataSource<SaleRecord>(
    boxName: StorageBoxes.sales,
    fromMap: SaleRecord.fromMap,
  );
  final CloudIdentityStore _identityStore;
  final CloudSyncCoordinator _syncCoordinator;

  CloudRepository<SaleRecord>? _cloud;
  String? _cloudStoreId;
  String? _cloudDeviceId;

  SaleRepository({
    CloudIdentityStore? identityStore,
    CloudSyncCoordinator? syncCoordinator,
  })  : _identityStore = identityStore ?? CloudIdentityStore(),
        _syncCoordinator = syncCoordinator ?? CloudSyncCoordinator.instance;

  @override
  Future<List<SaleRecord>> getAll() async {
    // Local-first: never block the UI waiting for Firestore.
    unawaited(_trySync());
    return _local.getAll();
  }

  @override
  Future<SaleRecord?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(SaleRecord entity) async {
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

  Future<CloudSyncResult?> restoreFromCloud() async {
    final cloud = await _getCloudRepository();
    if (cloud == null) return null;
    try {
      final storeId = await _identityStore.getStoreId();
      if (storeId == null || storeId.isEmpty) return null;
      return await _syncCoordinator.run<CloudSyncResult>(
        key: '$storeId:sales:restore',
        operation: cloud.restoreFromCloud,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Falló la restauración de Firestore.',
        name: 'STELLAR_POS.cloud_sync',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<CloudSyncResult?> _trySync([CloudRepository<SaleRecord>? existing]) async {
    final cloud = existing ?? await _getCloudRepository();
    if (cloud == null) return null;

    try {
      final storeId = await _identityStore.getStoreId();
      if (storeId == null || storeId.isEmpty) return null;

      return await _syncCoordinator.run<CloudSyncResult>(
        key: '$storeId:${CloudCollection.sales}',
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

  Future<CloudRepository<SaleRecord>?> _getCloudRepository() async {
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
    _cloud = CloudRepository<SaleRecord>(
      local: _local,
      cloud: FirestoreDataSource<SaleRecord>(
        storeId: storeId,
        collectionName: CloudCollection.sales,
        fromMap: SaleRecord.fromMap,
      ),
      scope: CloudSyncScope(
        storeId: storeId,
        deviceId: deviceId,
      ),
      collection: CloudCollection.sales,
      fromMap: SaleRecord.fromMap,
    );
    return _cloud;
  }

  /// Applies a single remote Firestore document to the local Hive cache.
  Future<bool> applyRemoteData(Map<String, dynamic> data) async {
    final cloud = await _getCloudRepository();
    if (cloud == null) return false;
    return cloud.applyRemoteData(data);
  }

  /// Applies a single remote Firestore deletion to the local Hive cache.
  Future<bool> applyRemoteDelete(String id) async {
    final cloud = await _getCloudRepository();
    if (cloud == null) return false;
    return cloud.applyRemoteDelete(id);
  }

}
