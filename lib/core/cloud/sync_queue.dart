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
  final String? storeId;

  const SyncQueueItem({
    required this.id,
    required this.collection,
    required this.entityId,
    required this.operation,
    required this.queuedAt,
    this.payload,
    this.attempts = 0,
    this.storeId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'collection': collection,
        'entityId': entityId,
        'operation': operation.name,
        'payload': payload,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
        'attempts': attempts,
        'storeId': storeId,
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
      storeId: map['storeId']?.toString() ??
          ((map['payload'] is Map)
              ? (map['payload'] as Map)['storeId']?.toString() ??
                  ((map['payload'] as Map)['metadata'] is Map
                      ? (map['payload'] as Map)['metadata']['storeId']?.toString()
                      : null)
              : null),
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
        storeId: storeId,
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
    String? storeId,
  }) async {
    await _replacePendingForEntity(
      collection: collection,
      entityId: entityId,
      storeId: storeId,
    );
    await _enqueue(
      SyncQueueItem(
        id: IdGenerator.newId(),
        collection: collection,
        entityId: entityId,
        storeId: storeId,
        operation: SyncOperationType.upsert,
        payload: Map<String, dynamic>.from(payload),
        queuedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Enqueues many upserts while opening/scanning the durable queue only once.
  /// This avoids the O(n²) behavior that appears when thousands of legacy
  /// records are migrated one by one and each item scans the existing queue.
  Future<void> enqueueUpserts({
    required String collection,
    required Iterable<SyncQueueItem> items,
    String? storeId,
  }) async {
    final pendingItems = items.toList(growable: false);
    if (pendingItems.isEmpty) return;

    final box = await LocalStorage.openBox(_boxName);
    final keysToDelete = <dynamic>[];
    final targetIds = <String>{
      for (final item in pendingItems) item.entityId,
    };

    for (final key in box.keys) {
      final value = box.get(key);
      if (value is! Map) continue;
      final existing = SyncQueueItem.fromMap(
        Map<String, dynamic>.from(value),
      );
      if (existing.collection == collection &&
          targetIds.contains(existing.entityId) &&
          (storeId == null ||
              existing.storeId == storeId ||
              existing.storeId == null)) {
        keysToDelete.add(key);
      }
    }

    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }

    final entries = <dynamic, dynamic>{
      for (final item in pendingItems) item.id: item.toMap(),
    };
    await box.putAll(entries);
  }

  Future<void> enqueueDelete({
    required String collection,
    required String entityId,
    Map<String, dynamic>? payload,
    String? storeId,
  }) async {
    await _replacePendingForEntity(
      collection: collection,
      entityId: entityId,
      storeId: storeId,
    );
    await _enqueue(
      SyncQueueItem(
        id: IdGenerator.newId(),
        collection: collection,
        entityId: entityId,
        storeId: storeId,
        operation: SyncOperationType.delete,
        payload: payload == null ? null : Map<String, dynamic>.from(payload),
        queuedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<SyncQueueItem>> pending({String? collection, String? storeId}) async {
    final box = await LocalStorage.openBox(_boxName);
    final items = <SyncQueueItem>[];
    for (final value in box.values) {
      if (value is! Map) continue;
      final item = SyncQueueItem.fromMap(Map<String, dynamic>.from(value));
      final itemStoreId = item.storeId;
      if ((collection == null || item.collection == collection) &&
          (storeId == null || itemStoreId == storeId)) {
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
    String? storeId,
  }) async {
    final box = await LocalStorage.openBox(_boxName);
    final keys = <dynamic>[];
    for (final key in box.keys) {
      final value = box.get(key);
      if (value is! Map) continue;
      final item = SyncQueueItem.fromMap(Map<String, dynamic>.from(value));
      if (item.collection == collection &&
          item.entityId == entityId &&
          (storeId == null || item.storeId == storeId)) {
        keys.add(key);
      }
    }
    for (final key in keys) {
      await box.delete(key);
    }
  }
}
