import 'package:stellar_pos/core/cloud/cloud_identity_store.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_service.dart';

/// Application-level entry point for selecting the cloud tenant.
///
/// A store id is never generated automatically. The caller must explicitly
/// provide the store id that represents the business whose data this device
/// is allowed to synchronize.
class CloudStoreService {
  final CloudIdentityStore identityStore;
  final CloudSyncService syncService;

  CloudStoreService({
    CloudIdentityStore? identityStore,
    CloudSyncService? syncService,
  })  : identityStore = identityStore ?? CloudIdentityStore(),
        syncService = syncService ?? CloudSyncService();

  Future<String?> getStoreId() => identityStore.getStoreId();

  Future<void> configureStore(String storeId) async {
    await identityStore.setStoreId(storeId);
    await syncService.syncAll();
  }

  Future<void> clearStore() => identityStore.clearStoreId();
}
