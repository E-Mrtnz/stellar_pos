import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stellar_pos/core/cloud_paths.dart';
import 'package:stellar_pos/core/cloud_record.dart';
import 'package:stellar_pos/core/cloud_firebase.dart';

/// Thin Firestore adapter for explicitly requested remote operations.
///
/// Constructing this adapter must not require Firebase to have been
/// initialized. Local-first code may create dependencies before the optional
/// Firebase bootstrap finishes; the SDK instance is resolved only after an
/// operation has passed [CloudFirebase.ensureReady].
class CloudFirestoreRepository {
  CloudFirestoreRepository({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  Future<void> create(
    String storeId,
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    await CloudFirebase.ensureReady();
    await _firestore
        .doc(CloudPaths.document(storeId, collection, documentId))
        .set(Map<String, dynamic>.from(data));
  }

  Future<CloudRecord?> read(
    String storeId,
    String collection,
    String documentId,
  ) async {
    await CloudFirebase.ensureReady();
    final snapshot = await _firestore
        .doc(CloudPaths.document(storeId, collection, documentId))
        .get();
    if (!snapshot.exists) return null;
    return CloudRecord(
      id: snapshot.id,
      data: Map<String, dynamic>.from(
        snapshot.data() ?? const <String, dynamic>{},
      ),
    );
  }

  Future<void> update(
    String storeId,
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    await CloudFirebase.ensureReady();
    await _firestore
        .doc(CloudPaths.document(storeId, collection, documentId))
        .update(Map<String, dynamic>.from(data));
  }

  Future<void> delete(
    String storeId,
    String collection,
    String documentId,
  ) async {
    await CloudFirebase.ensureReady();
    await _firestore
        .doc(CloudPaths.document(storeId, collection, documentId))
        .delete();
  }
}
