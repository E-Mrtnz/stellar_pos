import 'dart:developer' as developer;

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
  final int failed;
  final int migrated;

  const CloudSyncResult({
    this.uploaded = 0,
    this.downloaded = 0,
    this.deleted = 0,
    this.skippedConflicts = 0,
    this.failed = 0,
    this.migrated = 0,
  });

  CloudSyncResult operator +(CloudSyncResult other) => CloudSyncResult(
        uploaded: uploaded + other.uploaded,
        downloaded: downloaded + other.downloaded,
        deleted: deleted + other.deleted,
        skippedConflicts: skippedConflicts + other.skippedConflicts,
        failed: failed + other.failed,
        migrated: migrated + other.migrated,
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
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    var result = const CloudSyncResult();
    final startedAt = DateTime.now();

    // Legacy local records can outlive the first synchronization checkpoint.
    // Revisit only records that still have no tenant identity so a previous
    // failed migration can recover automatically without re-uploading already
    // acknowledged records on every cycle.
    final migratedLegacy = await _seedLegacyLocalPending(
      collection: collection,
      scope: scope,
      local: local,
      fromMap: fromMap,
    );
    result = result + CloudSyncResult(migrated: migratedLegacy);

    final checkpoint = await checkpoints.get(
      storeId: scope.storeId,
      collection: collection,
    );

    // Capture durable delete intent before the initial remote bootstrap too.
    // Otherwise an offline delete could be resurrected by the first getAll()
    // before the queue gets a chance to upload its tombstone.
    final pendingDeletesBeforeBootstrap = (await queue.pending(
      collection: collection,
      storeId: scope.storeId,
    ))
        .where((item) => item.operation == SyncOperationType.delete)
        .map((item) => item.entityId)
        .toSet();

    if (checkpoint == null) {
      final remote = await cloud.getAll();
      if (remote.isNotEmpty) {
        result = result + await _applyRemote(
          local: local,
          remote: remote,
          fromMap: fromMap,
          pendingDeletes: pendingDeletesBeforeBootstrap,
        );
      }

      // The first sync is a migration boundary. Existing local records that
      // have never been acknowledged by the cloud are queued so a previously
      // populated STELLAR POS installation is not silently lost.
      //
      // Before queueing them, assign the active store/device identity. This
      // prevents legacy local records (which may have no sync metadata yet)
      // from being uploaded without a tenant boundary.
      final seeded = await _seedLocalPending(
        collection: collection,
        scope: scope,
        local: local,
        fromMap: fromMap,
      );
      result = result + CloudSyncResult(migrated: seeded);
    }

    result = result + await _flushQueue(
      collection: collection,
      local: local,
      cloud: cloud,
      scope: scope,
      fromMap: fromMap,
    );

    // A failed offline delete remains in the durable queue while the local
    // record is already gone. Keep that tombstone intent in mind during the
    // pull so an older remote copy cannot resurrect the deleted record.
    final pendingDeletes = (await queue.pending(
      collection: collection,
      storeId: scope.storeId,
    ))
        .where((item) => item.operation == SyncOperationType.delete)
        .map((item) => item.entityId)
        .toSet();

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
      pendingDeletes: pendingDeletes,
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

    final elapsed = DateTime.now().difference(startedAt);
    developer.log(
      'Sincronización completada. Colección: ' + collection +
          ', migrados/encolados: ' + result.migrated.toString() +
          ', subidos: ' + result.uploaded.toString() +
          ', descargados: ' + result.downloaded.toString() +
          ', eliminados: ' + result.deleted.toString() +
          ', conflictos omitidos: ' + result.skippedConflicts.toString() +
          ', fallos: ' + result.failed.toString() +
          ', duración: ' + elapsed.inMilliseconds.toString() + ' ms.',
      name: 'STELLAR_POS.cloud_sync',
    );
    return result;
  }

  Future<int> _seedLegacyLocalPending<T extends SyncableEntity>({
    required String collection,
    required CloudSyncScope scope,
    required LocalDataSource<T> local,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    final stored = await local.getAll();
    final prepared = <T>[];

    for (final entity in stored) {
      if (entity.metadata.syncState == SyncState.deleted ||
          entity.metadata.storeId != null) {
        continue;
      }

      final metadata = scope.applyTo(
        SyncMetadata(
          createdAt: entity.metadata.createdAt,
          updatedAt: entity.metadata.updatedAt,
          version: entity.metadata.version,
          schemaVersion: entity.metadata.schemaVersion,
          syncState: SyncState.pending,
          lastSyncedAt: entity.metadata.lastSyncedAt,
          deletedAt: entity.metadata.deletedAt,
        ),
      );
      prepared.add(_withMetadata(entity, metadata, fromMap));
    }

    await _saveLocalBatch(local, prepared);
    await _enqueueUpserts(
      collection: collection,
      scope: scope,
      entities: prepared,
    );
    return prepared.length;
  }

  Future<int> _seedLocalPending<T extends SyncableEntity>({
    required String collection,
    required CloudSyncScope scope,
    required LocalDataSource<T> local,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    final stored = await local.getAll();
    final prepared = <T>[];

    for (final entity in stored) {
      if (entity.metadata.syncState == SyncState.deleted) {
        continue;
      }

      if (entity.metadata.storeId != null &&
          entity.metadata.storeId != scope.storeId) {
        continue;
      }

      // A record marked as synced is considered safe to skip only when it
      // already belongs to this store and has a real cloud acknowledgement.
      if (entity.metadata.syncState == SyncState.synced &&
          entity.metadata.storeId == scope.storeId &&
          entity.metadata.lastSyncedAt != null) {
        continue;
      }

      var nextEntity = entity;
      final metadataNeedsScope =
          entity.metadata.storeId != scope.storeId ||
          entity.metadata.deviceId != scope.deviceId;

      if (metadataNeedsScope ||
          entity.metadata.syncState != SyncState.pending) {
        final metadata = scope.applyTo(
          entity.metadata.touch(syncState: SyncState.pending),
        );
        nextEntity = _withMetadata(entity, metadata, fromMap);
      }

      prepared.add(nextEntity);
    }

    await _saveLocalBatch(local, prepared);
    await _enqueueUpserts(
      collection: collection,
      scope: scope,
      entities: prepared,
    );
    return prepared.length;
  }

  Future<void> _saveLocalBatch<T extends SyncableEntity>(
    LocalDataSource<T> local,
    List<T> entities,
  ) async {
    if (entities.isEmpty) return;

    final batchLocal = local is BatchLocalDataSource<T>
        ? local as BatchLocalDataSource<T>
        : null;
    if (batchLocal != null) {
      await batchLocal.saveAll(entities);
      return;
    }

    for (final entity in entities) {
      await local.save(entity);
    }
  }

  Future<void> _enqueueUpserts<T extends SyncableEntity>({
    required String collection,
    required CloudSyncScope scope,
    required List<T> entities,
  }) async {
    if (entities.isEmpty) return;

    final now = DateTime.now().toUtc();
    await queue.enqueueUpserts(
      collection: collection,
      storeId: scope.storeId,
      items: [
        for (var index = 0; index < entities.length; index++)
          SyncQueueItem(
            id: collection +
                ':' +
                entities[index].id +
                ':' +
                now.microsecondsSinceEpoch.toString() +
                ':' +
                index.toString(),
            collection: collection,
            entityId: entities[index].id,
            operation: SyncOperationType.upsert,
            payload: Map<String, dynamic>.from(entities[index].toMap()),
            queuedAt: now,
            storeId: scope.storeId,
          ),
      ],
    );
  }

  Future<CloudSyncResult> _flushQueue<T extends SyncableEntity>({
    required String collection,
    required LocalDataSource<T> local,
    required CloudDataSource<T> cloud,
    required CloudSyncScope scope,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    var result = const CloudSyncResult();
    final items = await queue.pending(
      collection: collection,
      storeId: scope.storeId,
    );

    // Independent Firestore writes are allowed to progress concurrently.
    // These remain individual writes rather than a Firestore batch, avoiding
    // security-rule access-call limits for large batches.
    const concurrency = 8;

    for (var offset = 0; offset < items.length; offset += concurrency) {
      final chunk = items
          .skip(offset)
          .take(concurrency)
          .toList(growable: false);

      final outcomes = await Future.wait(
        chunk.map(
          (item) => _flushQueueItem(
            item: item,
            collection: collection,
            local: local,
            cloud: cloud,
            fromMap: fromMap,
          ),
        ),
      );

      for (final outcome in outcomes) {
        result = result + outcome;
      }
    }

    return result;
  }

  Future<CloudSyncResult> _flushQueueItem<T extends SyncableEntity>({
    required SyncQueueItem item,
    required String collection,
    required LocalDataSource<T> local,
    required CloudDataSource<T> cloud,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    try {
      if (item.operation == SyncOperationType.delete) {
        final metadata = item.payload == null
            ? null
            : SyncMetadata.fromMap(item.payload!);
        await cloud.delete(item.entityId, metadata: metadata);
        await queue.remove(item.id);
        return const CloudSyncResult(uploaded: 1);
      }

      final current = await local.getById(item.entityId);
      if (current == null) {
        await queue.remove(item.id);
        return const CloudSyncResult();
      }

      await cloud.save(current);
      final synced = _withMetadata(
        current,
        current.metadata.markSynced(),
        fromMap,
      );
      await local.save(synced);
      await queue.remove(item.id);
      return const CloudSyncResult(uploaded: 1);
    } catch (error, stackTrace) {
      await queue.markAttempt(item.id, item.attempts + 1);
      developer.log(
        'No se pudo sincronizar un registro con Firestore. '
        'Colección: ' + collection + ', documento: ' + item.entityId + ', '
        'operación: ' + item.operation.name + ', intento: ' +
        (item.attempts + 1).toString() + '.',
        name: 'STELLAR_POS.cloud_sync',
        error: error,
        stackTrace: stackTrace,
      );
      return const CloudSyncResult(failed: 1);
    }
  }

  Future<CloudSyncResult> _applyRemote<T extends SyncableEntity>({
    required LocalDataSource<T> local,
    required List<T> remote,
    required T Function(Map<String, dynamic> map) fromMap,
    Set<String> pendingDeletes = const <String>{},
  }) async {
    var result = const CloudSyncResult();

    for (final remoteEntity in remote) {
      // The local deletion is authoritative until its durable queue entry
      // reaches Firestore. Do not resurrect the remote copy in the meantime.
      if (pendingDeletes.contains(remoteEntity.id)) {
        result = result + const CloudSyncResult(skippedConflicts: 1);
        continue;
      }

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
