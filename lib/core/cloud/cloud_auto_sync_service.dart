import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:stellar_pos/core/cloud/cloud_store_service.dart';

/// Keeps the active installation reconciled with Firestore without requiring
/// the user to open a specific module.
///
/// The POS remains local-first: every repository still saves to Hive first and
/// keeps queued changes when Firebase is unavailable. This service only adds a
/// periodic reconciliation while the app is active and an immediate pass when
/// the app resumes.
class CloudAutoSyncService with WidgetsBindingObserver {
  static const _syncInterval = Duration(seconds: 60);

  final CloudStoreService _storeService;
  Timer? _timer;
  bool _started = false;
  bool _syncing = false;

  CloudAutoSyncService({CloudStoreService? storeService})
      : _storeService = storeService ?? CloudStoreService();

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _scheduleTimer();
    unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    try {
      if (!await _storeService.isConfigured) return;
      await _storeService.sync();
    } catch (_) {
      // Cloud synchronization is best-effort. Individual repositories keep
      // local operation and durable queue entries when Firebase is offline.
    } finally {
      _syncing = false;
    }
  }

  void _scheduleTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_syncInterval, (_) {
      unawaited(syncNow());
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _scheduleTimer();
        unawaited(syncNow());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _stopTimer();
        break;
      case AppLifecycleState.detached:
        _stopTimer();
        break;
    }
  }

  void dispose() {
    _stopTimer();
    WidgetsBinding.instance.removeObserver(this);
  }
}
