import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stellar_pos/core/cloud_sync_retry_policy.dart';

/// Lifecycle-aware scheduler shell. It is deliberately not registered by the
/// application automatically: a caller must explicitly start it after the
/// user opts in. The supplied runner must enforce store membership and entity
/// allow-lists on every execution.
class CloudSyncScheduler with WidgetsBindingObserver {
  CloudSyncScheduler({
    required Future<void> Function() runBatch,
    CloudSyncRetryPolicy retryPolicy = const CloudSyncRetryPolicy(),
    this.interval = const Duration(seconds: 30),
    this.observeLifecycle = true,
  }) : _runBatch = runBatch, _retryPolicy = retryPolicy {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'El intervalo debe ser positivo.');
    }
  }

  final Future<void> Function() _runBatch;
  final CloudSyncRetryPolicy _retryPolicy;
  final Duration interval;
  final bool observeLifecycle;

  Timer? _timer;
  bool _started = false;
  bool _running = false;
  bool _rerunRequested = false;
  bool _lifecyclePaused = false;
  int _failedAttempts = 0;

  bool get isStarted => _started;
  bool get isRunning => _running;

  /// Starts scheduling only when explicitly called by an opt-in owner.
  void start() {
    if (_started) return;
    _started = true;
    if (observeLifecycle) WidgetsBinding.instance.addObserver(this);
    _schedule(Duration.zero);
  }

  /// Stops future runs without deleting pending outbox events or cursors.
  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
    if (observeLifecycle) WidgetsBinding.instance.removeObserver(this);
  }

  /// Requests a run. Concurrent requests are coalesced into one extra run.
  Future<void> runNow() async {
    if (!_started) return;
    if (_running) {
      _rerunRequested = true;
      return;
    }
    _timer?.cancel();
    _timer = null;
    _running = true;
    try {
      await _runBatch();
      _failedAttempts = 0;
      if (_started) _schedule(interval);
    } on Object {
      _failedAttempts++;
      if (_started) {
        final delay = _retryPolicy.canRetry(_failedAttempts)
            ? _retryPolicy.delayForAttempt(_failedAttempts)
            : interval;
        _schedule(delay);
      }
      rethrow;
    } finally {
      _running = false;
      if (_started && _rerunRequested) {
        _rerunRequested = false;
        _schedule(Duration.zero);
      }
    }
  }

  void _schedule(Duration delay) {
    if (!_started || _lifecyclePaused) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      runNow().catchError((Object _) {
        // The next retry is already scheduled by runNow.
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started || !observeLifecycle) return;
    if (state == AppLifecycleState.resumed) {
      _lifecyclePaused = false;
      _schedule(Duration.zero);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _lifecyclePaused = true;
      _timer?.cancel();
      _timer = null;
    }
  }

  void dispose() => stop();
}
