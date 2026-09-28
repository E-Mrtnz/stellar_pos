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
  Future<void> delete(String id) async {
    // Physical deletion is deliberately kept out of the synchronization
    // protocol. Repositories should send a tombstone with deletedAt instead.
    await _collection.doc(id).set(
      {
        'id': id,
        'metadata': {
          'syncState': SyncState.deleted.name,
          'deletedAt': DateTime.now().toUtc().toIso8601String(),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> markSynced(T entity) async {
    final synced = entity.metadata.markSynced();
    await _collection.doc(entity.id).set(
      _cloudSafeMap(entity.toMap()..['metadata'] = synced.toMap()),
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
