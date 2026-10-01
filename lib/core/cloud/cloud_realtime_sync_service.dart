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
/// collection. That preserves the local-first conflict rules, tenant scoping,
/// retry behavior, and delete tombstones.
class CloudRealtimeSyncService extends ChangeNotifier
    with WidgetsBindingObserver {
  final CloudSyncService _syncService;
  final FirebaseFirestore _firestore;

  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _listeners = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final Map<String, Future<void>> _applying =
      <String, Future<void>>{};
  final Map<String, List<Map<String, dynamic>>> _pendingDocuments =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, Set<String>> _pendingDeletes =
      <String, Set<String>>{};

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
    // Local writes are already reflected in Hive. Wait for the server
    // acknowledgement before treating the event as a remote change.
    if (snapshot.metadata.hasPendingWrites) return;
    if (snapshot.docChanges.isEmpty) return;

    final documents = <Map<String, dynamic>>[];
    final deletedIds = <String>[];

    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        deletedIds.add(change.doc.id);
        continue;
      }

      final raw = change.doc.data();
      if (raw == null) continue;
      final data = Map<String, dynamic>.from(raw);
      data['id'] ??= change.doc.id;
      documents.add(data);
    }

    _scheduleRemoteChanges(
      collection,
      documents: documents,
      deletedIds: deletedIds,
    );
  }

  void _scheduleRemoteChanges(
    String collection, {
    required Iterable<Map<String, dynamic>> documents,
    required Iterable<String> deletedIds,
  }) {
    if (!_active || _storeId == null) return;

    final pendingDocuments = _pendingDocuments.putIfAbsent(
      collection,
      () => <Map<String, dynamic>>[],
    );
    pendingDocuments.addAll(documents);

    final pendingDeletes = _pendingDeletes.putIfAbsent(
      collection,
      () => <String>{},
    );
    pendingDeletes.addAll(deletedIds);

    if (_applying.containsKey(collection)) return;

    final future = _runRemoteChanges(collection);
    _applying[collection] = future;
  }

  Future<void> _runRemoteChanges(String collection) async {
    try {
      do {
        final documents = List<Map<String, dynamic>>.from(
          _pendingDocuments.remove(collection) ?? const <Map<String, dynamic>>[],
        );
        final deletedIds = Set<String>.from(
          _pendingDeletes.remove(collection) ?? const <String>{},
        );

        if (documents.isEmpty && deletedIds.isEmpty) break;

        try {
          await _syncService.applyRemoteChanges(
            collection,
            documents: documents,
            deletedIds: deletedIds,
          );
          _lastSyncedCollection = collection;
          notifyListeners();
        } catch (_) {
          // Keep realtime delivery best-effort. The periodic synchronization
          // path remains responsible for recovering a failed remote apply.
          break;
        }
      } while (_active &&
          _storeId != null &&
          (_pendingDocuments.containsKey(collection) ||
              _pendingDeletes.containsKey(collection)));
    } finally {
      _applying.remove(collection);
    }
  }

  Future<void> _cancelListeners() async {
    final subscriptions = _listeners.values.toList(growable: false);
    _listeners.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    _pendingDocuments.clear();
    _pendingDeletes.clear();
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
