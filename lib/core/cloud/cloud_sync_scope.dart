import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Runtime identity used by synchronization.
///
/// A store is the tenant boundary. A device id identifies the origin of a
/// local change and is kept in metadata for diagnostics/conflict handling.
class CloudSyncScope {
  final String storeId;
  final String deviceId;

  const CloudSyncScope({
    required this.storeId,
    required this.deviceId,
  });

  CloudSyncScope copyWith({
    String? storeId,
    String? deviceId,
  }) =>
      CloudSyncScope(
        storeId: storeId ?? this.storeId,
        deviceId: deviceId ?? this.deviceId,
      );

  SyncMetadata applyTo(SyncMetadata metadata) => SyncMetadata(
        createdAt: metadata.createdAt,
        updatedAt: metadata.updatedAt,
        version: metadata.version,
        schemaVersion: metadata.schemaVersion,
        syncState: metadata.syncState,
        lastSyncedAt: metadata.lastSyncedAt,
        deletedAt: metadata.deletedAt,
        deviceId: deviceId,
        storeId: storeId,
      );
}
