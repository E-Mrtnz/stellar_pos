import 'package:stellar_pos/core/cloud/cloud_data_source.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_scope.dart';
import 'package:stellar_pos/core/cloud/sync_checkpoint_store.dart';
import 'package:stellar_pos/core/cloud/sync_queue.dart';
import 'package:stellar_pos/core/data/datasources/data_source.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

class CloudSyncResult {
  final int uploaded;
  final int downloaded;
  final int deleted;
  final int skippedConflicts;

  const CloudSyncResult({
    this.uploaded = 0,
    this.downloaded = 0,
    this.deleted = 0,
    this.skippedConflicts = 0,
  });

  CloudSyncResult operator +(CloudSyncResult other) => CloudSyncResult(
        uploaded: uploaded + other.uploaded,
        downloaded: downloaded + other.downloaded,
        deleted: deleted + other.deleted,
        skippedConflicts: skippedConflicts + other.skippedConflicts,
      );
}

/// Incremental synchronization engine.
///
/// The sequence is deliberately deterministic:
/// 1. bootstrap/consume local pending changes;
/// 2. download only documents newer than the last checkpoint;
/// 3. apply remote data only when it does not replace a newer local change;
/// 4. advance the checkpoint only after the pull completed successfully.
class CloudSyncEngine {
  final SyncQueue queue;
  final SyncCheckpointStore checkpoints;

  CloudSyncEngine({
    SyncQueue? queue,
    SyncCheckpointStore? checkpoints,
  })  : queue = queue ?? SyncQueue(),
        checkpoints = checkpoints ?? SyncCheckpointStore();

  Future<CloudSyncResult> sync<T extends SyncableEntity>({
    required String collection,
    required CloudSyncScope scope,
    required LocalDataSource<T> local,
    required CloudDataSource<T> cloud,
    required CloudSyncScope scope,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    var result = const CloudSyncResult();
    final checkpoint = await checkpoints.get(
      storeId: scope.storeId,
      collection: collection,
    );

    if (checkpoint == null) {
      final remote = await cloud.getAll();
      if (remote.isNotEmpty) {
        result = result + await _applyRemote(
          local: local,
          remote: remote,
          fromMap: fromMap,
        );
      }

      // The first sync is a migration boundary. Existing local records that
      // have never been acknowledged by the cloud are queued so a previously
      // populated STELLAR POS installation is not silently lost.
      //
      // Before queueing them, assign the active store/device identity. This
      // prevents legacy local records (which may have no sync metadata yet)
      // from being uploaded without a tenant boundary.
      await _seedLocalPending(
        collection: collection,
        scope: scope,
        local: local,
        fromMap: fromMap,
      );
    }

    result = result + await _flushQueue(
      collection: collection,
      local: local,
      cloud: cloud,
      scope: scope,
      fromMap: fromMap,
    );

    final afterUploadCheckpoint = await checkpoints.get(
      storeId: scope.storeId,
      collection: collection,
    );

    // Re-read a tiny overlap window so two writes that receive the same
    // timestamp precision are not skipped by the next incremental pull.
    final pullSince = afterUploadCheckpoint?.subtract(
      const Duration(milliseconds: 1),
    );
    final changed = pullSince == null
        ? await cloud.getAll()
        : await cloud.getChangedSince(pullSince);

    result = result + await _applyRemote(
      local: local,
      remote: changed,
      fromMap: fromMap,
    );

    final timestamps = <DateTime>[
      if (afterUploadCheckpoint != null) afterUploadCheckpoint,
      ...changed.map((entity) => entity.metadata.updatedAt.toUtc()),
    ];
    if (timestamps.isNotEmpty) {
      timestamps.sort();
      await checkpoints.save(
        storeId: scope.storeId,
        collection: collection,
        timestamp: timestamps.last,
      );
    }

    return result;
  }

  Future<void> _seedLocalPending<T extends SyncableEntity>({
    required String collection,
    required CloudSyncScope scope,
    required LocalDataSource<T> local,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    final stored = await local.getAll();
    for (final entity in stored) {
      if (entity.metadata.syncState == SyncState.deleted ||
          entity.metadata.syncState == SyncState.synced) {
        continue;
      }

      if (entity.metadata.storeId != null &&
          entity.metadata.storeId != scope.storeId) {
        continue;
      }

      var prepared = entity;

      final metadataNeedsScope =
          entity.metadata.storeId != scope.storeId ||
          entity.metadata.deviceId != scope.deviceId;

      if (metadataNeedsScope ||
          entity.metadata.syncState != SyncState.pending) {
        final metadata = scope.applyTo(
          entity.metadata.touch(syncState: SyncState.pending),
        );
        prepared = _withMetadata(entity, metadata, fromMap);
        await local.save(prepared);
      }

      await queue.enqueueUpsert(
        collection: collection,
        entityId: prepared.id,
        payload: prepared.toMap(),
        storeId: scope.storeId,
      );
    }
  }

  Future<CloudSyncResult> _flushQueue<T extends SyncableEntity>({
    required String collection,
    required LocalDataSource<T> local,
    required CloudDataSource<T> cloud,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    var result = const CloudSyncResult();
    final items = await queue.pending(collection: collection);

    for (final item in items) {
      try {
        if (item.operation == SyncOperationType.delete) {
          final metadata = item.payload == null
              ? null
              : SyncMetadata.fromMap(item.payload!);
          await cloud.delete(item.entityId, metadata: metadata);
          await queue.remove(item.id);
          result = result + const CloudSyncResult(uploaded: 1);
          continue;
        }

        final current = await local.getById(item.entityId);
        if (current == null) {
          await queue.remove(item.id);
          continue;
        }

        await cloud.save(current);
        final synced = _withMetadata(
          current,
          current.metadata.markSynced(),
          fromMap,
        );
        await local.save(synced);
        await queue.remove(item.id);
        result = result + const CloudSyncResult(uploaded: 1);
      } catch (_) {
        await queue.markAttempt(item.id, item.attempts + 1);
        // Offline/network failures stay durable in the queue for the next run.
        break;
      }
    }

    return result;
  }

  Future<CloudSyncResult> _applyRemote<T extends SyncableEntity>({
    required LocalDataSource<T> local,
    required List<T> remote,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    var result = const CloudSyncResult();

    for (final remoteEntity in remote) {
      final localEntity = await local.getById(remoteEntity.id);

      if (remoteEntity.metadata.syncState == SyncState.deleted) {
        if (localEntity == null) {
          // There is nothing to remove locally. The checkpoint still advances
          // so the tombstone is not reprocessed forever.
          continue;
        }

        final localState = localEntity.metadata.syncState;
        if (localState == SyncState.pending ||
            localState == SyncState.updated) {
          // Never let an older remote tombstone erase a local mutation that
          // has not been acknowledged by the cloud yet.
          result = result + const CloudSyncResult(skippedConflicts: 1);
          continue;
        }

        if (_remoteIsNewer(remoteEntity, localEntity)) {
          await local.delete(remoteEntity.id);
          result = result + const CloudSyncResult(deleted: 1);
        } else {
          result = result + const CloudSyncResult(skippedConflicts: 1);
        }
        continue;
      }

      if (localEntity == null) {
        await local.save(_withMetadata(
          remoteEntity,
          remoteEntity.metadata.markSynced(),
          fromMap,
        ));
        result = result + const CloudSyncResult(downloaded: 1);
        continue;
      }

      final localState = localEntity.metadata.syncState;
      if (localState == SyncState.pending ||
          localState == SyncState.updated) {
        // A local mutation has not been acknowledged by the cloud yet.
        // Keep it intact; its queue entry will upload it on the next pass.
        result = result + const CloudSyncResult(skippedConflicts: 1);
        continue;
      }

      if (_remoteIsNewer(remoteEntity, localEntity)) {
        await local.save(_withMetadata(
          remoteEntity,
          remoteEntity.metadata.markSynced(),
          fromMap,
        ));
        result = result + const CloudSyncResult(downloaded: 1);
      }
    }

    return result;
  }

  bool _remoteIsNewer<T extends SyncableEntity>(T remote, T local) {
    final remoteVersion = remote.metadata.version;
    final localVersion = local.metadata.version;
    if (remoteVersion != localVersion) {
      return remoteVersion > localVersion;
    }

    final remoteTime = remote.metadata.updatedAt.toUtc();
    final localTime = local.metadata.updatedAt.toUtc();
    if (remoteTime != localTime) {
      return remoteTime.isAfter(localTime);
    }

    final remoteDevice = remote.metadata.deviceId ?? '';
    final localDevice = local.metadata.deviceId ?? '';
    return remoteDevice.compareTo(localDevice) > 0;
  }

  T _withMetadata<T extends SyncableEntity>(
    T entity,
    SyncMetadata metadata,
    T Function(Map<String, dynamic> map) fromMap,
  ) {
    final map = Map<String, dynamic>.from(entity.toMap());
    map['metadata'] = metadata.toMap();
    return fromMap(map);
  }
}
