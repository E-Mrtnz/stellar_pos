import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stellar_pos/core/cloud_firebase.dart';
import 'package:stellar_pos/core/cloud_inventory_ledger_inbox.dart';
import 'package:stellar_pos/core/cloud_inventory_ledger_pull.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_worker.dart';

/// Explicit composition for a membership-gated, durable inventory-ledger pull.
///
/// This factory does not start background work or mutate Product.stock. Pulled
/// movements are stored in the durable inbox until a store-scoped inventory
/// repository can reconcile them safely with the active catalog.
Future<CloudInventoryLedgerSyncService> createCloudInventoryLedgerSyncService({
  FirebaseFunctions? functions,
  FirebaseAuth? auth,
  FirebaseFirestore? firestore,
  CloudSyncCursorStore? cursors,
  CloudInventoryLedgerInbox? inbox,
}) async {
  await CloudFirebase.ensureReady();
  final sessionGate = FirebaseCloudSyncSessionGate(
    auth: auth,
    firestore: firestore,
  );
  final coordinator = CloudInventoryLedgerPullCoordinator(
    transport: CloudFunctionsInventoryLedgerPullTransport(
      functions: functions,
    ),
    applier: inbox ?? CloudInventoryLedgerInbox(),
    cursors: cursors ?? CloudSyncCursorStore(),
  );
  return CloudInventoryLedgerSyncService(
    coordinator: coordinator,
    sessionGate: sessionGate,
  );
}

/// One explicit pull operation. A missing or inactive membership pauses the
/// operation without fetching remote data.
class CloudInventoryLedgerSyncService {
  const CloudInventoryLedgerSyncService({
    required CloudInventoryLedgerPullCoordinator coordinator,
    required CloudSyncSessionGate sessionGate,
  }) : _coordinator = coordinator,
       _sessionGate = sessionGate;

  final CloudInventoryLedgerPullCoordinator _coordinator;
  final CloudSyncSessionGate _sessionGate;

  Future<CloudInventoryLedgerPage?> pullOnce({
    required String storeId,
    required String deviceId,
    int limit = 50,
  }) async {
    if (storeId.trim().isEmpty || storeId.contains('/') ||
        deviceId.trim().isEmpty || deviceId.contains('/')) {
      throw ArgumentError('storeId y deviceId deben ser identificadores válidos.');
    }
    if (!await _sessionGate.canSyncStore(storeId)) return null;
    return _coordinator.pullOnce(
      storeId: storeId,
      deviceId: deviceId,
      limit: limit,
    );
  }
}
