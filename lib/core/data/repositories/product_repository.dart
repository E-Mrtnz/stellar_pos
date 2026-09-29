import 'package:stellar_pos/core/cloud/cloud_collection.dart';
import 'package:stellar_pos/core/cloud/cloud_identity_store.dart';
import 'package:stellar_pos/core/cloud/cloud_repository.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_scope.dart';
import 'package:stellar_pos/core/cloud/firestore_data_source.dart';
import 'package:stellar_pos/core/data/datasources/hive_data_source.dart';
import 'package:stellar_pos/core/data/storage/storage_boxes.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/product.dart';

/// Product repository with local-first persistence and optional cloud sync.
///
/// Hive remains the local source of truth for normal POS operation. When a
/// store has been configured for cloud synchronization, Firestore is used
/// through [CloudRepository] and never exposed to the presentation layer.
class ProductRepository implements Repository<Product> {
  final HiveDataSource<Product> _local = HiveDataSource<Product>(
    boxName: StorageBoxes.products,
    fromMap: Product.fromMap,
  );
  final CloudIdentityStore _identityStore;

  CloudRepository<Product>? _cloud;
  String? _cloudStoreId;
  String? _cloudDeviceId;

  ProductRepository({CloudIdentityStore? identityStore})
      : _identityStore = identityStore ?? CloudIdentityStore();

  @override
  Future<List<Product>> getAll() async {
    await _trySync();
    return _local.getAll();
  }

  @override
  Future<Product?> getById(String id) => _local.getById(id);

  @override
  Future<void> save(Product entity) async {
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
  ///
  /// Synchronization is intentionally optional until a store is explicitly
  /// assigned to this installation. A missing store identity therefore keeps
  /// the application fully local instead of inventing a tenant identifier.
  Future<void> sync() => _trySync();

  Future<void> _trySync([CloudRepository<Product>? existing]) async {
    final cloud = existing ?? await _getCloudRepository();
    if (cloud == null) return;

    try {
      await cloud.sync();
    } catch (_) {
      // Local POS operation must remain available when Firebase is offline,
      // unavailable, or temporarily rejects the request. The queued change
      // remains durable and can be retried by the next synchronization.
    }
  }

  Future<CloudRepository<Product>?> _getCloudRepository() async {
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
    _cloud = CloudRepository<Product>(
      local: _local,
      cloud: FirestoreDataSource<Product>(
        storeId: storeId,
        collectionName: CloudCollection.products,
        fromMap: Product.fromMap,
      ),
      scope: CloudSyncScope(
        storeId: storeId,
        deviceId: deviceId,
      ),
      collection: CloudCollection.products,
      fromMap: Product.fromMap,
    );
    return _cloud;
  }
}
