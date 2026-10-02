import 'package:firebase_core/firebase_core.dart';

/// Optional Firebase initialization boundary.
///
/// Firebase never becomes a prerequisite for starting the local POS.
class FirebaseBootstrap {
  const FirebaseBootstrap._();
  static bool _initialized = false;
  static Object? _lastError;
  static bool get isInitialized => _initialized;
  static Object? get lastError => _lastError;

  static Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _initialized = true;
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = error;
      return false;
    }
  }
}
