import 'dart:developer' as developer;

import 'package:stellar_pos/core/cloud/cloud_data_source.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_scope.dart';
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
  final List<String> errors;

  const CloudSyncResult({
    this.uploaded = 0,
    this.downloaded = 0,
    this.deleted = 0,
    this.skippedConflicts = 0,
    this.failed = 0,
    this.migrated = 0,
    this.errors = const <String>[],
  });

  CloudSyncResult operator +(CloudSyncResult other) => CloudSyncResult(
        uploaded: uploaded + other.uploaded,
        downloaded: downloaded + other.downloaded,
        deleted: deleted + other.deleted,
        skippedConflicts: skippedConflicts + other.skippedConflicts,
        failed: failed + other.failed,
        migrated: migrated + other.migrated,
        errors: <String>[...errors, ...other.errors],
      );
}

/// Local-first cloud synchronization engine.
///
/// The synchronization path intentionally follows the same simple lifecycle
/// used successfully by the client repository:
///
/// 1. Read the local Hive snapshot.
/// 2. Give legacy/local pending records the active store scope.
/// 3. Upload local pending changes directly to Firestore.
/// 4. Pull the remote snapshot and reconcile records that are newer remotely.
/// 5. Keep failed local changes pending so the next automatic pass retries them.
///
/// There is no migration checkpoint and no upsert queue in the critical path.
/// The local database is the source of truth and every repository can retry
/// its pending records on the next access/save without getting blocked by a
/// global queue.
class CloudSyncEngine {
  final SyncQueue queue;

  CloudSyncEngine({
    SyncQueue? queue,
  }) : queue = queue ?? SyncQueue();

  static const _operationTimeout = Duration(seconds: 15);
  static const _concurrency = 4;

  Future<CloudSyncResult> sync<T extends SyncableEntity>({
    required String collection,
    required CloudSyncScope scope,
    required LocalDataSource<T> local,
    required CloudDataSource<T> cloud,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    var result = const CloudSyncResult();
    final startedAt = DateTime.now().toUtc();

    try {
      final stored = await local.getAll();
      final prepared = <T>[];
      final pendingUploads = <T>[];

      for (final entity in stored) {
        if (entity.metadata.syncState == SyncState.deleted) {
          continue;
        }

        final belongsToAnotherStore = entity.metadata.storeId != null &&
            entity.metadata.storeId != scope.storeId;
        if (belongsToAnotherStore) {
          continue;
        }

        var nextEntity = entity;

        // Legacy records have no tenant identity. Assign the current store
        // without changing their business fields, and mark them pending so
        // they are migrated exactly once to the cloud.
        if (entity.metadata.storeId != scope.storeId ||
            entity.metadata.deviceId != scope.deviceId) {
          final metadata = scope.applyTo(
            entity.metadata.touch(syncState: SyncState.pending),
          );
          nextEntity = _withMetadata(entity, metadata, fromMap);
          result = result + const CloudSyncResult(migrated: 1);
        }

        prepared.add(nextEntity);

        if (nextEntity.metadata.syncState == SyncState.pending ||
            nextEntity.metadata.syncState == SyncState.updated) {
          pendingUploads.add(nextEntity);
        }
      }

      if (prepared.isNotEmpty) {
        await _saveLocalBatch(local, prepared);
      }

      // Deletes use a tiny durable queue because the local entity has already
      // been removed from Hive. Upserts do not need a queue: the entity itself
      // remains locally available and will be retried on the next pass.
      result = result + await _flushPendingDeletes(
        collection: collection,
        scope: scope,
        cloud: cloud,
      );

      // Upload local mutations before performing the remote reconciliation.
      // This is important during initial migration: a slow/failed remote query
      // must not prevent local records from reaching Firestore.
      result = result + await _uploadPending(
        collection: collection,
        local: local,
        cloud: cloud,
        fromMap: fromMap,
        entities: pendingUploads,
      );

      // Remote reads are best-effort. A remote read timeout must never freeze
      // the entire automatic synchronization cycle.
      List<T>? remote;
      try {
        remote = await cloud.getAll().timeout(_operationTimeout);
      } catch (error, stackTrace) {
        developer.log(
          'No se pudo leer la colección remota durante la reconciliación. '
          'La subida local continuará en el siguiente ciclo. '
          'Colección: ' + collection + '.',
          name: 'STELLAR_POS.cloud_sync',
          error: error,
          stackTrace: stackTrace,
        );
      }

      if (remote != null) {
        final pendingDeleteIds = (await queue.pending(
        collection: collection,
        storeId: scope.storeId,
      ))
          .where((item) => item.operation == SyncOperationType.delete)
          .map((item) => item.entityId)
          .toSet();

      result = result + await _reconcileRemote(
        local: local,
        localSnapshot: prepared,
        remote: remote,
        pendingDeleteIds: pendingDeleteIds,
        fromMap: fromMap,
      );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Falló la sincronización de la colección ' + collection + '.',
        name: 'STELLAR_POS.cloud_sync',
        error: error,
        stackTrace: stackTrace,
      );
      result = result + CloudSyncResult(
        failed: 1,
        errors: <String>[
          collection + ': ' + error.toString(),
        ],
      );
    }

    final elapsed = DateTime.now().toUtc().difference(startedAt);
    developer.log(
      'Sincronización completada. Colección: ' +
          collection +
          ', subidos: ' +
          result.uploaded.toString() +
          ', descargados: ' +
          result.downloaded.toString() +
          ', eliminados: ' +
          result.deleted.toString() +
          ', fallos: ' +
          result.failed.toString() +
          ', duración: ' +
          elapsed.inMilliseconds.toString() +
          ' ms.',
      name: 'STELLAR_POS.cloud_sync',
    );

    return result;
  }

  /// Restores a newly joined device from the store's remote snapshot.
  ///
  /// This path is deliberately different from normal local-first sync:
  /// existing local records are treated as pre-join cache data and are not
  /// uploaded into the joined store. The remote store is authoritative for
  /// onboarding. Local records absent remotely are removed.
  Future<CloudSyncResult> restoreFromCloud<T extends SyncableEntity>({
    required String collection,
    required LocalDataSource<T> local,
    required CloudDataSource<T> cloud,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    var result = const CloudSyncResult();
    final startedAt = DateTime.now().toUtc();

    try {
      final remote = await cloud.getAll().timeout(_operationTimeout);
      final localSnapshot = await local.getAll();
      final remoteById = <String, T>{
        for (final entity in remote) entity.id: entity,
      };

      // Remove any pre-join local records that do not belong to the cloud
      // snapshot. They must never leak into the newly joined store.
      for (final localEntity in localSnapshot) {
        if (!remoteById.containsKey(localEntity.id)) {
          await local.delete(localEntity.id);
        }
      }

      for (final remoteEntity in remote) {
        if (remoteEntity.metadata.syncState == SyncState.deleted) {
          await local.delete(remoteEntity.id);
          result = result + const CloudSyncResult(deleted: 1);
          continue;
        }

        await local.save(
          _withMetadata(
            remoteEntity,
            remoteEntity.metadata.markSynced(),
            fromMap,
          ),
        );
        result = result + const CloudSyncResult(downloaded: 1);
      }
    } catch (error, stackTrace) {
      developer.log(
        'No se pudo restaurar la colección desde Firestore. Colección: ' +
            collection +
            '.',
        name: 'STELLAR_POS.cloud_sync',
        error: error,
        stackTrace: stackTrace,
      );
      result = result + CloudSyncResult(
        failed: 1,
        errors: <String>[collection + ': ' + error.toString()],
      );
    }

    final elapsed = DateTime.now().toUtc().difference(startedAt);
    developer.log(
      'Restauración desde Firestore completada. Colección: ' +
          collection +
          ', descargados: ' +
          result.downloaded.toString() +
          ', eliminados: ' +
          result.deleted.toString() +
          ', fallos: ' +
          result.failed.toString() +
          ', duración: ' +
          elapsed.inMilliseconds.toString() +
          ' ms.',
      name: 'STELLAR_POS.cloud_sync',
    );

    return result;
  }

  Future<CloudSyncResult> _uploadPending<T extends SyncableEntity>({
    required String collection,
    required LocalDataSource<T> local,
    required CloudDataSource<T> cloud,
    required T Function(Map<String, dynamic> map) fromMap,
    required List<T> entities,
  }) async {
    if (entities.isEmpty) return const CloudSyncResult();

    var result = const CloudSyncResult();

    for (var offset = 0; offset < entities.length; offset += _concurrency) {
      final chunk = entities
          .skip(offset)
          .take(_concurrency)
          .toList(growable: false);

      final outcomes = await Future.wait(
        chunk.map(
          (entity) => _uploadOne(
            collection: collection,
            entity: entity,
            cloud: cloud,
          ),
        ),
      );

      final synced = <T>[];
      for (var index = 0; index < outcomes.length; index++) {
        final outcome = outcomes[index];
        if (outcome.success) {
          synced.add(
            _withMetadata(
              chunk[index],
              chunk[index].metadata.markSynced(),
              fromMap,
            ),
          );
          result = result + const CloudSyncResult(uploaded: 1);
        } else {
          result = result + CloudSyncResult(
            failed: 1,
            errors: <String>[
              collection + '/' + chunk[index].id + ': ' + (outcome.error ?? 'Error desconocido.'),
            ],
          );
        }
      }

      await _saveLocalBatch(local, synced);
    }

    return result;
  }

  Future<_UploadOutcome> _uploadOne<T extends SyncableEntity>({
    required String collection,
    required T entity,
    required CloudDataSource<T> cloud,
  }) async {
    try {
      await cloud.save(entity).timeout(_operationTimeout);
      return const _UploadOutcome.success();
    } catch (error, stackTrace) {
      developer.log(
        'No se pudo subir un registro. Colección: ' +
            collection +
            ', documento: ' +
            entity.id +
            '.',
        name: 'STELLAR_POS.cloud_sync',
        error: error,
        stackTrace: stackTrace,
      );
      return _UploadOutcome.failure(error.toString());
    }
  }

  Future<CloudSyncResult> _flushPendingDeletes<T extends SyncableEntity>({
    required String collection,
    required CloudSyncScope scope,
    required CloudDataSource<T> cloud,
  }) async {
    final items = await queue.pending(
      collection: collection,
      storeId: scope.storeId,
    );

    if (items.isEmpty) return const CloudSyncResult();

    var result = const CloudSyncResult();

    for (var offset = 0; offset < items.length; offset += _concurrency) {
      final chunk = items
          .skip(offset)
          .take(_concurrency)
          .toList(growable: false);

      final outcomes = await Future.wait(
        chunk.map(
          (item) => _deleteOne(
            item: item,
            collection: collection,
            cloud: cloud,
          ),
        ),
      );

      for (var index = 0; index < outcomes.length; index++) {
        final outcome = outcomes[index];
        if (outcome.success) {
          await queue.remove(chunk[index].id);
          result = result + const CloudSyncResult(deleted: 1);
        } else {
          result = result + CloudSyncResult(
            failed: 1,
            errors: <String>[
              collection + '/' + chunk[index].entityId + ': ' + (outcome.error ?? 'Error desconocido.'),
            ],
          );
        }
      }
    }

    return result;
  }

  Future<_UploadOutcome> _deleteOne<T extends SyncableEntity>({
    required SyncQueueItem item,
    required String collection,
    required CloudDataSource<T> cloud,
  }) async {
    try {
      final metadata = item.payload == null
          ? null
          : SyncMetadata.fromMap(item.payload!);
      await cloud.delete(item.entityId, metadata: metadata)
          .timeout(_operationTimeout);
      return const _UploadOutcome.success();
    } catch (error, stackTrace) {
      developer.log(
        'No se pudo subir un borrado. Colección: ' +
            collection +
            ', documento: ' +
            item.entityId +
            '.',
        name: 'STELLAR_POS.cloud_sync',
        error: error,
        stackTrace: stackTrace,
      );
      return _UploadOutcome.failure(error.toString());
    }
  }

  Future<CloudSyncResult> _reconcileRemote<T extends SyncableEntity>({
    required LocalDataSource<T> local,
    required List<T> localSnapshot,
    required List<T> remote,
    required Set<String> pendingDeleteIds,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    var result = const CloudSyncResult();

    final localById = <String, T>{
      for (final entity in localSnapshot) entity.id: entity,
    };

    for (final remoteEntity in remote) {
      final localEntity = localById[remoteEntity.id];

      // A failed local delete is still authoritative for this synchronization
      // cycle. Do not re-download the remote copy while its tombstone remains
      // pending in the durable delete queue.
      if (pendingDeleteIds.contains(remoteEntity.id)) {
        result = result + const CloudSyncResult(skippedConflicts: 1);
        continue;
      }

      if (remoteEntity.metadata.syncState == SyncState.deleted) {
        if (localEntity == null) {
          continue;
        }

        if (localEntity.metadata.syncState == SyncState.pending ||
            localEntity.metadata.syncState == SyncState.updated) {
          result = result + const CloudSyncResult(skippedConflicts: 1);
          continue;
        }

        if (_remoteIsNewer(remoteEntity, localEntity)) {
          await local.delete(remoteEntity.id);
          result = result + const CloudSyncResult(deleted: 1);
        }
        continue;
      }

      if (localEntity == null) {
        await local.save(
          _withMetadata(
            remoteEntity,
            remoteEntity.metadata.markSynced(),
            fromMap,
          ),
        );
        result = result + const CloudSyncResult(downloaded: 1);
        continue;
      }

      final localState = localEntity.metadata.syncState;
      if (localState == SyncState.pending ||
          localState == SyncState.updated) {
        // Local changes were uploaded before this pull. They remain the local
        // authority until the next pass confirms the cloud copy.
        result = result + const CloudSyncResult(skippedConflicts: 1);
        continue;
      }

      if (_remoteIsNewer(remoteEntity, localEntity)) {
        await local.save(
          _withMetadata(
            remoteEntity,
            remoteEntity.metadata.markSynced(),
            fromMap,
          ),
        );
        result = result + const CloudSyncResult(downloaded: 1);
      }
    }

    return result;
  }

  bool _remoteIsNewer<T extends SyncableEntity>(T remote, T local) {
    if (remote.metadata.version != local.metadata.version) {
      return remote.metadata.version > local.metadata.version;
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

  Future<void> _saveLocalBatch<T extends SyncableEntity>(
    LocalDataSource<T> local,
    List<T> entities,
  ) async {
    if (entities.isEmpty) return;

    // LocalDataSource exposes only the basic CRUD contract. Keep the
    // synchronization engine compatible with every local data source.
    await Future.wait(
      entities.map(local.save),
    );
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

class _UploadOutcome {
  final bool success;
  final String? error;

  const _UploadOutcome.success()
      : success = true,
        error = null;

  const _UploadOutcome.failure(this.error) : success = false;
}
