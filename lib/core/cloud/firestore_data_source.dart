import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stellar_pos/core/cloud/cloud_collection.dart';
import 'package:stellar_pos/core/cloud/cloud_data_source.dart';
import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Firestore implementation of the cloud persistence contract.
///
/// Firestore remains behind this data-source boundary. The rest of the app
/// works with domain models and does not know about Firebase SDK types.
class FirestoreDataSource<T extends SyncableEntity>
    implements CloudDataSource<T> {
  final FirebaseFirestore firestore;
  final String storeId;
  final String collectionName;
  final T Function(Map<String, dynamic> map) fromMap;

  FirestoreDataSource({
    required this.storeId,
    required this.collectionName,
    required this.fromMap,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(
        CloudCollection.collection(
          storeId: storeId,
          collection: collectionName,
        ),
      );

  @override
  Future<List<T>> getAll() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => fromMap(_withDocumentId(doc)))
        .toList(growable: false);
  }

  @override
  Future<List<T>> getChangedSince(DateTime timestamp) async {
    final snapshot = await _collection
        .where(
          'metadata.updatedAt',
          isGreaterThan: timestamp.toUtc().toIso8601String(),
        )
        .get();

    return snapshot.docs
        .map((doc) => fromMap(_withDocumentId(doc)))
        .toList(growable: false);
  }

  @override
  Future<T?> getById(String id) async {
    final snapshot = await _collection.doc(id).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return fromMap(_withDocumentId(snapshot));
  }

  @override
  Future<void> save(T entity) async {
    await _collection.doc(entity.id).set(
          _cloudSafeMap(entity.toMap()),
          SetOptions(merge: false),
        );
  }

  @override
  Future<void> delete(String id, {SyncMetadata? metadata}) async {
    // Physical deletion is deliberately kept out of the synchronization
    // protocol. A tombstone remains long enough for other devices to observe
    // the deletion during incremental synchronization.
    final now = DateTime.now().toUtc();
    final existing = await _collection.doc(id).get();
    final existingData = existing.data();
    final existingMetadata = existingData?['metadata'] is Map
        ? Map<String, dynamic>.from(existingData!['metadata'] as Map)
        : <String, dynamic>{};

    final baseMetadata = metadata ??
        SyncMetadata(
          createdAt: DateTime.tryParse(
                existingMetadata['createdAt']?.toString() ?? '',
              )?.toUtc() ??
              now,
          updatedAt: now,
          version: existingMetadata['version'] is num
              ? (existingMetadata['version'] as num).toInt()
              : 0,
          schemaVersion: existingMetadata['schemaVersion'] is num
              ? (existingMetadata['schemaVersion'] as num).toInt()
              : 1,
          syncState: SyncState.pending,
          lastSyncedAt: DateTime.tryParse(
            existingMetadata['lastSyncedAt']?.toString() ?? '',
          )?.toUtc(),
          deviceId: existingMetadata['deviceId']?.toString(),
          storeId: existingMetadata['storeId']?.toString() ?? storeId,
        );

    final tombstone = baseMetadata.touch(
      syncState: SyncState.deleted,
      now: now,
      deleted: true,
    );

    await _collection.doc(id).set(
      {
        'id': id,
        'metadata': tombstone.toMap(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> markSynced(T entity) async {
    final synced = entity.metadata.markSynced();
    final payload = Map<String, dynamic>.from(entity.toMap());
    payload['metadata'] = synced.toMap();
    await _collection.doc(entity.id).set(
      _cloudSafeMap(payload),
      SetOptions(merge: false),
    );
  }

  Map<String, dynamic> _withDocumentId(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = Map<String, dynamic>.from(document.data()!);
    data['id'] ??= document.id;
    return data;
  }

  Map<String, dynamic> _cloudSafeMap(Map<String, dynamic> source) =>
      _normalize(source);

  Map<String, dynamic> _normalize(Map<String, dynamic> source) {
    return source.map(
      (key, value) => MapEntry(key, _normalizeValue(value)),
    );
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is Map) {
      return _normalize(Map<String, dynamic>.from(value));
    }
    if (value is Iterable) {
      return value.map(_normalizeValue).toList(growable: false);
    }
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value;
  }
}
