import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Pure conflict-resolution rules. Keeping this independent of storage makes
/// synchronization deterministic and testable before a cloud provider exists.
class SyncPolicy {
  const SyncPolicy();

  SyncMetadata chooseLatest(SyncMetadata local, SyncMetadata remote) {
    if (remote.version > local.version) return remote;
    if (local.version > remote.version) return local;
    return remote.updatedAt.isAfter(local.updatedAt) ? remote : local;
  }
}
