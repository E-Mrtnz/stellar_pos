import 'dart:async';
import 'dart:convert';

import 'package:stellar_pos/core/cloud_sync_outbox.dart';
import 'package:stellar_pos/core/cloud_sync_protocol.dart';
import 'package:stellar_pos/core/data/storage/local_storage.dart';

/// A durable write-ahead record for a local mutation that must also enter the
/// sync outbox. This journal does not make two Hive boxes transactional; instead
/// it records intent first and makes every subsequent step replayable.
enum CloudMutationJournalStatus { prepared, localApplied, eventQueued, completed }

class CloudMutationJournalEntry {
  const CloudMutationJournalEntry({
    required this.mutationId,
    required this.storeId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.localVersion,
    required this.createdAt,
    required this.localMutation,
    required this.eventPayload,
    this.status = CloudMutationJournalStatus.prepared,
  });

  final String mutationId;
  final String storeId;
  final String entityType;
  final String entityId;
  final CloudSyncOperation operation;
  final int localVersion;
  final DateTime createdAt;
  final Map<String, Object?> localMutation;
  final Map<String, Object?> eventPayload;
  final CloudMutationJournalStatus status;

  String get eventId => mutationId;

  CloudMutationJournalEntry copyWith({CloudMutationJournalStatus? status}) =>
      CloudMutationJournalEntry(
        mutationId: mutationId,
        storeId: storeId,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        localVersion: localVersion,
        createdAt: createdAt,
        localMutation: localMutation,
        eventPayload: eventPayload,
        status: status ?? this.status,
      );

  Map<String, Object?> toMap() => <String, Object?>{
    'mutationId': mutationId,
    'storeId': storeId,
    'entityType': entityType,
    'entityId': entityId,
    'operation': operation.name,
    'localVersion': localVersion,
    'createdAt': createdAt.toIso8601String(),
    'localMutation': localMutation,
    'eventPayload': eventPayload,
    'status': status.name,
  };

  factory CloudMutationJournalEntry.fromMap(Map<String, dynamic> map) {
    final operation = CloudSyncOperation.values.where((value) => value.name == map['operation']).firstOrNull;
    final status = CloudMutationJournalStatus.values.where((value) => value.name == map['status']).firstOrNull;
    final createdAt = DateTime.tryParse(map['createdAt']?.toString() ?? '');
    if (operation == null || status == null || createdAt == null ||
        map['mutationId'] is! String || map['storeId'] is! String ||
        map['entityType'] is! String || map['entityId'] is! String ||
        map['localVersion'] is! int || map['localMutation'] is! Map ||
        map['eventPayload'] is! Map) {
      throw const FormatException('Registro de diario de sincronización inválido.');
    }
    return CloudMutationJournalEntry(
      mutationId: map['mutationId'] as String,
      storeId: map['storeId'] as String,
      entityType: map['entityType'] as String,
      entityId: map['entityId'] as String,
      operation: operation,
      localVersion: map['localVersion'] as int,
      createdAt: createdAt,
      localMutation: Map<String, Object?>.from(map['localMutation'] as Map),
      eventPayload: Map<String, Object?>.from(map['eventPayload'] as Map),
      status: status,
    );
  }
}

abstract interface class CloudMutationJournalStorage {
  Object? get(String key);
  Iterable<Object?> get values;
  Future<void> put(String key, Object value);
  Future<void> flush();
}

class _HiveCloudMutationJournalStorage implements CloudMutationJournalStorage {
  _HiveCloudMutationJournalStorage(this.boxName);
  final String boxName;
  Map<String, Object?> _cache = <String, Object?>{};
  Future<dynamic> get _box => _open();

  Future<dynamic> _open() async {
    // Reuse the same local-storage initializer as the outbox.
    return LocalStorage.openBox(boxName);
  }

  Future<void> _refresh() async {
    final box = await _box;
    _cache = <String, Object?>{
      for (final key in box.keys) key as String: box.get(key) as Object?,
    };
  }

  @override
  Object? get(String key) => _cache[key];
  @override
  Iterable<Object?> get values => _cache.values;
  @override
  Future<void> put(String key, Object value) async {
    final box = await _box;
    await box.put(key, value);
    await _refresh();
  }
  @override
  Future<void> flush() async => (await _box).flush();
}

/// Executes/replays a local mutation using a caller-supplied idempotent applier.
/// The applier must use stable entity IDs and must not emit a second sync event.
class CloudMutationJournal {
  CloudMutationJournal({
    required this.outbox,
    this.boxName = 'cloud_mutation_journal',
    CloudMutationJournalStorage? storage,
  }) : _storage = storage ?? _HiveCloudMutationJournalStorage(boxName);

  final CloudSyncOutbox outbox;
  final String boxName;
  final CloudMutationJournalStorage _storage;
  Future<void> _tail = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try { result.complete(await action()); }
      on Object catch (error, stack) { result.completeError(error, stack); }
    });
    return result.future;
  }

  Future<void> commit({
    required CloudMutationJournalEntry entry,
    required Future<void> Function(Map<String, Object?> mutation) applyLocal,
  }) => _serialize(() async {
    await _refreshIfHive();
    final existing = _storage.get(entry.mutationId);
    if (existing != null) {
      final previous = _decode(existing);
      if (!_sameIntent(previous, entry)) {
        throw StateError('El ID de mutación ya existe con otro contenido.');
      }
      await _finish(previous, applyLocal);
      return;
    }
    _validate(entry);
    await _storage.put(entry.mutationId, jsonDecode(jsonEncode(entry.toMap())) as Object);
    await _storage.flush();
    await _finish(entry, applyLocal);
  });

  /// Replays incomplete intents after app restart. Apply callback must be
  /// idempotent; replay is expected if the process stopped between steps.
  Future<int> recover({
    required Future<void> Function(Map<String, Object?> mutation) applyLocal,
    String? storeId,
    int limit = 100,
  }) => _serialize(() async {
    if (limit < 1 || limit > 500) throw ArgumentError.value(limit, 'limit');
    await _refreshIfHive();
    final entries = _storage.values.map(_decode).where((entry) =>
      entry.status != CloudMutationJournalStatus.completed &&
      (storeId == null || entry.storeId == storeId)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    var recovered = 0;
    for (final entry in entries.take(limit)) {
      await _finish(entry, applyLocal);
      recovered++;
    }
    return recovered;
  });

  Future<void> _finish(
    CloudMutationJournalEntry initial,
    Future<void> Function(Map<String, Object?> mutation) applyLocal,
  ) async {
    var entry = initial;
    if (entry.status == CloudMutationJournalStatus.prepared) {
      await applyLocal(Map<String, Object?>.from(entry.localMutation));
      entry = entry.copyWith(status: CloudMutationJournalStatus.localApplied);
      await _persist(entry);
    }
    if (entry.status == CloudMutationJournalStatus.localApplied) {
      await outbox.enqueue(CloudSyncEvent(
        eventId: entry.eventId,
        storeId: entry.storeId,
        entityType: entry.entityType,
        entityId: entry.entityId,
        operation: entry.operation,
        localVersion: entry.localVersion,
        createdAt: entry.createdAt,
        payload: entry.eventPayload,
      ));
      entry = entry.copyWith(status: CloudMutationJournalStatus.eventQueued);
      await _persist(entry);
    }
    if (entry.status == CloudMutationJournalStatus.eventQueued) {
      await _persist(entry.copyWith(status: CloudMutationJournalStatus.completed));
    }
  }

  Future<void> _persist(CloudMutationJournalEntry entry) async {
    await _storage.put(entry.mutationId, jsonDecode(jsonEncode(entry.toMap())) as Object);
    await _storage.flush();
  }

  Future<void> _refreshIfHive() async {
    if (_storage is _HiveCloudMutationJournalStorage) await _storage._refresh();
  }

  CloudMutationJournalEntry _decode(Object? raw) {
    if (raw is! Map) throw const FormatException('Registro de diario corrupto.');
    return CloudMutationJournalEntry.fromMap(Map<String, dynamic>.from(raw));
  }

  void _validate(CloudMutationJournalEntry entry) {
    if (entry.mutationId.trim().isEmpty || entry.mutationId.contains('/') ||
        entry.storeId.trim().isEmpty || entry.storeId.contains('/') ||
        entry.entityType.trim().isEmpty || entry.entityId.trim().isEmpty ||
        entry.localVersion < 0) {
      throw ArgumentError('Identidad de mutación inválida.');
    }
    final event = CloudSyncEvent(
      eventId: entry.eventId, storeId: entry.storeId,
      entityType: entry.entityType, entityId: entry.entityId,
      operation: entry.operation, localVersion: entry.localVersion,
      createdAt: entry.createdAt, payload: entry.eventPayload,
    );
    final error = validateCloudSyncEvent(event, activeStoreId: entry.storeId);
    if (error != null) throw ArgumentError('Evento inválido: $error');
    jsonEncode(entry.toMap());
  }

  bool _sameIntent(CloudMutationJournalEntry a, CloudMutationJournalEntry b) =>
      a.storeId == b.storeId && a.entityType == b.entityType &&
      a.entityId == b.entityId && a.operation == b.operation &&
      a.localVersion == b.localVersion && a.createdAt == b.createdAt &&
      _canonical(a.localMutation) == _canonical(b.localMutation) &&
      _canonical(a.eventPayload) == _canonical(b.eventPayload);

  String _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
    }
    if (value is List) return '[${value.map(_canonical).join(',')}]';
    return jsonEncode(value);
  }
}
