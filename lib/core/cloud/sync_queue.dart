import 'package:stellar_pos/core/data/storage/local_storage.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

enum SyncOperationType { upsert, delete }

class SyncQueueItem {
  final String id;
  final String collection;
  final String entityId;
  final SyncOperationType operation;
  final Map<String, dynamic>? payload;
  final DateTime queuedAt;
  final int attempts;

  const SyncQueueItem({
    required this.id,
    required this.collection,
    required this.entityId,
    required this.operation,
    required this.queuedAt,
    this.payload,
    this.attempts = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'collection': collection,
        'entityId': entityId,
        'operation': operation.name,
        'payload': payload,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
        'attempts': attempts,
      };

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id']?.toString() ?? '',
      collection: map['collection']?.toString() ?? '',
      entityId: map['entityId']?.toString() ?? '',
      operation: SyncOperationType.values.firstWhere(
        (value) => value.name == map['operation']?.toString(),
        orElse: () => SyncOperationType.upsert,
      ),
      payload: map['payload'] is Map
          ? Map<String, dynamic>.from(map['payload'] as Map)
          : null,
      queuedAt: DateTime.tryParse(map['queuedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      attempts: map['attempts'] is num
          ? (map['attempts'] as num).toInt()
          : int.tryParse(map['attempts']?.toString() ?? '') ?? 0,
    );
  }

  SyncQueueItem copyWith({int? attempts}) => SyncQueueItem(
        id: id,
        collection: collection,
        entityId: entityId,
        operation: operation,
        payload: payload,
        queuedAt: queuedAt,
        attempts: attempts ?? this.attempts,
      );
}

/// Durable local queue for changes that still need to reach Firestore.
///
/// The queue is intentionally independent from Firestore's offline cache so
/// the application retains control over its own local source of truth.
class SyncQueue {
  static const _boxName = 'cloud_sync_queue';

  Future<void> enqueueUpsert({
    required String collection,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    await _replacePendingForEntity(
      collection: collection,
      entityId: entityId,
      operation: SyncOperationType.upsert,
    );
    await _enqueue(
      SyncQueueItem(
        id: IdGenerator.newId(),
        collection: collection,
        entityId: entityId,
        operation: SyncOperationType.upsert,
        payload: Map<String, dynamic>.from(payload),
        queuedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> enqueueDelete({
    required String collection,
    required String entityId,
  }) async {
    await _replacePendingForEntity(
      collection: collection,
      entityId: entityId,
      operation: SyncOperationType.delete,
    );
    await _enqueue(
      SyncQueueItem(
        id: IdGenerator.newId(),
        collection: collection,
        entityId: entityId,
        operation: SyncOperationType.delete,
        queuedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<SyncQueueItem>> pending({String? collection}) async {
    final box = await LocalStorage.openBox(_boxName);
    final items = <SyncQueueItem>[];
    for (final value in box.values) {
      if (value is! Map) continue;
      final item = SyncQueueItem.fromMap(Map<String, dynamic>.from(value));
      if (collection == null || item.collection == collection) {
        items.add(item);
      }
    }
    items.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return items;
  }

  Future<void> remove(String queueId) async {
    final box = await LocalStorage.openBox(_boxName);
    await box.delete(queueId);
  }

  Future<void> markAttempt(String queueId, int attempts) async {
    final box = await LocalStorage.openBox(_boxName);
    final value = box.get(queueId);
    if (value is! Map) return;
    final item = SyncQueueItem.fromMap(Map<String, dynamic>.from(value));
    await box.put(queueId, item.copyWith(attempts: attempts).toMap());
  }

  Future<void> clearCollection(String collection) async {
    final box = await LocalStorage.openBox(_boxName);
    final ids = <dynamic>[];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value is Map &&
          Map<String, dynamic>.from(value)['collection']?.toString() ==
              collection) {
        ids.add(key);
      }
    }
    for (final key in ids) {
      await box.delete(key);
    }
  }

  Future<void> _enqueue(SyncQueueItem item) async {
    final box = await LocalStorage.openBox(_boxName);
    await box.put(item.id, item.toMap());
  }

  Future<void> _replacePendingForEntity({
    required String collection,
    required String entityId,
    required SyncOperationType operation,
  }) async {
    final box = await LocalStorage.openBox(_boxName);
    final keys = <dynamic>[];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value is! Map) continue;
      final item = SyncQueueItem.fromMap(Map<String, dynamic>.from(value));
      if (item.collection == collection &&
          item.entityId == entityId &&
          item.operation == operation) {
        keys.add(key);
      }
    }
    for (final key in keys) {
      await box.delete(key);
    }
  }
}
