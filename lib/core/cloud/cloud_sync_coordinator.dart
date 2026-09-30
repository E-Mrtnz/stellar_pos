import 'dart:developer' as developer;

/// Coordinates cloud synchronization across repository instances.
///
/// STELLAR POS can create more than one [ProductRepository] in the provider
/// tree. Without coordination, two repositories can start the same Firestore
/// sync at the same time, competing for the durable queue and checkpoint.
/// This coordinator collapses those overlapping calls into one operation per
/// store/collection while leaving the actual synchronization logic in the
/// cloud repository/engine.
class CloudSyncCoordinator {
  CloudSyncCoordinator._();

  static final CloudSyncCoordinator instance = CloudSyncCoordinator._();

  final Map<String, Future<void>> _inFlight = <String, Future<void>>{};

  Future<void> run({
    required String key,
    required Future<void> Function() operation,
  }) {
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _runAndRelease(key, operation);
    _inFlight[key] = future;
    return future;
  }

  Future<void> _runAndRelease(
    String key,
    Future<void> Function() operation,
  ) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      developer.log(
        'Falló una sincronización de Firestore. Clave: ' + key,
        name: 'STELLAR_POS.cloud_sync',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }
}
