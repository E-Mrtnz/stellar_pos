import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stellar_pos/core/cloud_paths.dart';
import 'package:stellar_pos/core/cloud_record.dart';
import 'package:stellar_pos/core/cloud_firebase.dart';

class CloudFirestoreRepository {
  CloudFirestoreRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Future<void> create(String storeId, String collection, String documentId, Map<String, dynamic> data) async {
    await CloudFirebase.ensureReady();
    await _firestore.doc(CloudPaths.document(storeId, collection, documentId)).set(Map<String, dynamic>.from(data));
  }

  Future<CloudRecord?> read(String storeId, String collection, String documentId) async {
    await CloudFirebase.ensureReady();
    final snapshot = await _firestore.doc(CloudPaths.document(storeId, collection, documentId)).get();
    if (!snapshot.exists) return null;
    return CloudRecord(id: snapshot.id, data: Map<String, dynamic>.from(snapshot.data() ?? const <String, dynamic>{}));
  }

  Future<void> update(String storeId, String collection, String documentId, Map<String, dynamic> data) async {
    await CloudFirebase.ensureReady();
    await _firestore.doc(CloudPaths.document(storeId, collection, documentId)).update(Map<String, dynamic>.from(data));
  }

  Future<void> delete(String storeId, String collection, String documentId) async {
    await CloudFirebase.ensureReady();
    await _firestore.doc(CloudPaths.document(storeId, collection, documentId)).delete();
  }
}
