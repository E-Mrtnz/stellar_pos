import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:stellar_pos/firebase_options.dart';

/// Describes Firebase SDK initialization only; it does not guarantee that
/// Firestore is reachable or that a user is authenticated.
enum CloudFirebaseStatus {
  notStarted,
  initializing,
  initialized,
  unavailable,
}

/// Optional Firebase bootstrap.
///
/// Local persistence and app startup must never depend on this completing.
/// A failed attempt is exposed as state and can be retried explicitly later.
class CloudFirebase {
  CloudFirebase._();

  static bool _ready = false;
  static Object? lastError;
  static Future<bool>? _initialization;

  static final ValueNotifier<CloudFirebaseStatus> status =
      ValueNotifier<CloudFirebaseStatus>(CloudFirebaseStatus.notStarted);

  static bool get isReady => _ready;

  /// Initializes Firebase without throwing. Concurrent callers share the same
  /// attempt, preventing duplicate initialization races.
  static Future<bool> initialize() {
    if (_ready) return Future<bool>.value(true);

    final inFlight = _initialization;
    if (inFlight != null) return inFlight;

    final attempt = _initializeOnce();
    _initialization = attempt;
    return attempt.whenComplete(() {
      if (identical(_initialization, attempt)) {
        _initialization = null;
      }
    });
  }

  static Future<bool> _initializeOnce() async {
    status.value = CloudFirebaseStatus.initializing;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      _ready = true;
      lastError = null;
      status.value = CloudFirebaseStatus.initialized;
      return true;
    } catch (error) {
      _ready = false;
      lastError = error;
      status.value = CloudFirebaseStatus.unavailable;
      return false;
    }
  }

  /// Explicit retry hook for a future settings/status UI.
  static Future<bool> retry() => initialize();

  /// Use only for operations that explicitly require Firebase. Ordinary local
  /// workflows must not call this method.
  static Future<void> ensureReady() async {
    if (!await initialize()) {
      throw StateError('Firebase no está disponible: $lastError');
    }
  }
}
