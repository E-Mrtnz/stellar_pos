import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Initializes Firebase without coupling the app to generated platform
/// configuration.
///
/// The actual Firebase project configuration is intentionally supplied by
/// FlutterFire when the project is connected to Firebase. No credentials or
/// project ids are hard-coded in the application source.
abstract final class CloudFirebase {
  static bool get isInitialized => Firebase.apps.isNotEmpty;

  static Future<FirebaseApp> initialize({
    required FirebaseOptions options,
  }) async {
    if (Firebase.apps.isNotEmpty) {
      return Firebase.app();
    }

    final app = await Firebase.initializeApp(options: options);

    // STELLAR POS keeps Hive as its application cache/offline store. Firestore
    // is therefore the cloud source of truth rather than the offline cache.
    FirebaseFirestore.instance;

    return app;
  }
}
