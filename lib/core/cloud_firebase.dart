import 'package:firebase_core/firebase_core.dart';

class CloudFirebase {
  static bool _ready = false;
  static Object? lastError;
  static bool get isReady => _ready;

  static Future<bool> initialize() async {
    if (_ready) return true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _ready = true;
      lastError = null;
      return true;
    } catch (error) {
      lastError = error;
      return false;
    }
  }

  static Future<void> ensureReady() async {
    if (!await initialize()) throw StateError('Firebase no está disponible.');
  }
}
