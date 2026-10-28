import 'package:stellar_pos/core/cloud_ledger_sync.dart';
import 'package:stellar_pos/core/cloud_sync_cursor_store.dart';
import 'package:stellar_pos/core/cloud_sync_worker.dart';

/// Membership-gated wrapper for an explicit ledger pull. The underlying
/// coordinator applies each page and commits its cursor only after all local
/// projections succeed. This wrapper is not registered with app startup.
class CloudLedgerPullSyncCoordinator {
  CloudLedgerPullSyncCoordinator({
    required CloudLedgerGateway gateway,
    required CloudLedgerRemoteApplier applier,
    required CloudSyncCursorStore cursors,
    required CloudSyncSessionGate sessionGate,
  }) : _pull = CloudLedgerPullCoordinator(
          gateway: gateway,
          applier: applier,
          cursors: cursors,
        ),
       _sessionGate = sessionGate;

  final CloudLedgerPullCoordinator _pull;
  final CloudSyncSessionGate _sessionGate;

  Future<CloudLedgerPullPage?> pullOnce({
    required String storeId,
    required String deviceId,
    int limit = 50,
  }) async {
    if (!await _sessionGate.canSyncStore(storeId)) return null;
    return _pull.pullOnce(
      storeId: storeId,
      deviceId: deviceId,
      limit: limit,
    );
  }
}
