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

  final Map<String, Future<dynamic>> _inFlight = <String, Future<dynamic>>{};

  Future<T> run<T>({
    required String key,
    required Future<T> Function() operation,
  }) {
    final existing = _inFlight[key];
    if (existing != null) return existing.then((value) => value as T);

    final future = _runAndRelease<T>(key, operation);
    _inFlight[key] = future;
    return future;
  }

  Future<T> _runAndRelease<T>(
    String key,
    Future<T> Function() operation,
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
