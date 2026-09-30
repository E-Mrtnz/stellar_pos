import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:stellar_pos/core/cloud/cloud_collection.dart';
import 'package:stellar_pos/core/cloud/cloud_sync_service.dart';

/// Keeps cloud-aware collections synchronized as soon as Firestore reports
/// changes from the server.
///
/// This service does not write remote snapshots directly into Hive. A remote
/// event only schedules the existing synchronization engine for the affected
/// collection. That preserves the local-first conflict rules, durable queue,
/// tombstones, tenant scoping, and checkpoint handling already implemented in
/// [CloudSyncService].
class CloudRealtimeSyncService extends ChangeNotifier
    with WidgetsBindingObserver {
  final CloudSyncService _syncService;
  final FirebaseFirestore _firestore;

  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _listeners = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final Map<String, Future<void>> _syncing =
      <String, Future<void>>{};
  final Set<String> _pendingTriggers = <String>{};

  String? _storeId;
  String? _lastSyncedCollection;
  bool _started = false;
  bool _active = true;

  String? get lastSyncedCollection => _lastSyncedCollection;

  CloudRealtimeSyncService({
    CloudSyncService? syncService,
    FirebaseFirestore? firestore,
  })  : _syncService = syncService ?? CloudSyncService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Starts lifecycle handling. The actual listeners are attached when a
  /// store id is configured through [setStoreId].
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _active = true;
    unawaited(_refreshListeners());
  }

  /// Updates the tenant watched by the listeners.
  ///
  /// Passing null removes every listener. This is important when the store
  /// identity is cleared or before a store has been configured.
  Future<void> setStoreId(String? storeId) async {
    final normalized = storeId?.trim();
    final next = normalized == null || normalized.isEmpty ? null : normalized;
    if (_storeId == next) {
      if (_active) {
        await _refreshListeners();
      }
      return;
    }

    _storeId = next;
    await _refreshListeners();
  }

  Future<void> _refreshListeners() async {
    if (!_started || !_active || _storeId == null) {
      await _cancelListeners();
      return;
    }

    final storeId = _storeId!;
    if (_listeners.isNotEmpty) {
      final expectedPathPrefix = CloudCollection.store(storeId);
      final currentMatches = _listeners.keys.every(
        (collection) =>
            _listeners[collection] != null &&
            CloudCollection.collection(
                  storeId: storeId,
                  collection: collection,
                )
                    .startsWith(expectedPathPrefix),
      );
      if (currentMatches &&
          _listeners.length == _collectionNames.length) {
        return;
      }
      await _cancelListeners();
    }

    for (final collection in _collectionNames) {
      final path = CloudCollection.collection(
        storeId: storeId,
        collection: collection,
      );
      final subscription = _firestore
          .collection(path)
          .snapshots()
          .listen(
            (snapshot) => _onSnapshot(collection, snapshot),
            onError: (_) {
              // Firestore automatically attempts to re-establish listeners.
              // The 60-second reconciliation remains the final fallback if
              // a listener is temporarily unavailable.
            },
          );
      _listeners[collection] = subscription;
    }
  }

  void _onSnapshot(
    String collection,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    // Ignore snapshots caused only by this installation's pending local
    // writes. The local repository has already persisted those changes and
    // its durable queue is responsible for uploading them.
    if (snapshot.metadata.hasPendingWrites) return;

    _scheduleSync(collection);
  }

  void _scheduleSync(String collection) {
    if (!_active || _storeId == null) return;

    if (_syncing.containsKey(collection)) {
      _pendingTriggers.add(collection);
      return;
    }

    final future = _runCollectionSync(collection);
    _syncing[collection] = future;
  }

  Future<void> _runCollectionSync(String collection) async {
    try {
      do {
        _pendingTriggers.remove(collection);
        try {
          await _syncService.syncCollection(collection);
          _lastSyncedCollection = collection;
          notifyListeners();
        } catch (_) {
          // Realtime synchronization is best-effort. The durable queue and
          // periodic 60-second reconciliation remain responsible for recovery.
          break;
        }
      } while (_active &&
          _storeId != null &&
          _pendingTriggers.contains(collection));
    } finally {
      _syncing.remove(collection);
      if (_active &&
          _storeId != null &&
          _pendingTriggers.remove(collection)) {
        _scheduleSync(collection);
      }
    }
  }

  Future<void> _cancelListeners() async {
    final subscriptions = _listeners.values.toList(growable: false);
    _listeners.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    _pendingTriggers.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasActive = _active;
    _active = state == AppLifecycleState.resumed;

    if (_active && !wasActive) {
      unawaited(_refreshListeners());
      return;
    }

    if (!_active && wasActive) {
      unawaited(_cancelListeners());
    }
  }

  void dispose() {
    _started = false;
    _active = false;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cancelListeners());
    super.dispose();
  }

  static const List<String> _collectionNames = <String>[
    CloudCollection.products,
    CloudCollection.sales,
    CloudCollection.purchases,
    CloudCollection.clients,
    CloudCollection.debtMovements,
    CloudCollection.clientGroups,
    CloudCollection.providerRoutes,
    CloudCollection.providerCatalog,
    CloudCollection.electronicBalanceAccounts,
    CloudCollection.electronicBalanceTransactions,
  ];
}
