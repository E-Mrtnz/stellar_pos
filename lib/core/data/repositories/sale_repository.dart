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

  /// Performs a best-effort synchronization for the configured store.
  Future<void> sync() => _trySync();

  Future<void> _trySync([CloudRepository<SaleRecord>? existing]) async {
    final cloud = existing ?? await _getCloudRepository();
    if (cloud == null) return;

    try {
      final storeId = await _identityStore.getStoreId();
      if (storeId == null || storeId.isEmpty) return;

      await _syncCoordinator.run(
        key: '$storeId:${CloudCollection.sales}',
        operation: cloud.sync,
      );
    } catch (_) {
      // Keep checkout/history available while Firebase is unavailable or
      // while the cloud tenant/security configuration is not ready.
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
}
