/// Lifecycle state used by the future synchronization engine.
enum SyncState { pending, synced, updated, deleted }

/// Metadata shared by every persisted entity.
///
/// Business fields remain independent from synchronization concerns so local
/// and remote data sources can exchange the same record without the UI knowing
/// which database is being used.
class SyncMetadata {
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final SyncState syncState;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  final String? deviceId;

  const SyncMetadata({
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.syncState = SyncState.pending,
    this.lastSyncedAt,
    this.deletedAt,
    this.deviceId,
  });

  factory SyncMetadata.initial({String? deviceId}) {
    final now = DateTime.now().toUtc();
    return SyncMetadata(
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
    );
  }

  SyncMetadata touch({
    SyncState? syncState,
    DateTime? now,
    bool deleted = false,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return SyncMetadata(
      createdAt: createdAt,
      updatedAt: timestamp,
      version: version + 1,
      syncState: deleted ? SyncState.deleted : (syncState ?? SyncState.updated),
      lastSyncedAt: lastSyncedAt,
      deletedAt: deleted ? timestamp : deletedAt,
      deviceId: deviceId,
    );
  }

  SyncMetadata markSynced({DateTime? at}) {
    final timestamp = (at ?? DateTime.now()).toUtc();
    return SyncMetadata(
      createdAt: createdAt,
      updatedAt: updatedAt,
      version: version,
      syncState: SyncState.synced,
      lastSyncedAt: timestamp,
      deletedAt: deletedAt,
      deviceId: deviceId,
    );
  }

  Map<String, dynamic> toMap() => {
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'version': version,
        'syncState': syncState.name,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'deviceId': deviceId,
      };

  factory SyncMetadata.fromMap(Map<String, dynamic> map) {
    final created = _dateTime(map['createdAt']) ?? DateTime.now().toUtc();
    final updated = _dateTime(map['updatedAt']) ?? created;
    return SyncMetadata(
      createdAt: created,
      updatedAt: updated,
      version: _int(map['version'], fallback: 1),
      syncState: _syncState(map['syncState']),
      lastSyncedAt: _dateTime(map['lastSyncedAt']),
      deletedAt: _dateTime(map['deletedAt']),
      deviceId: map['deviceId']?.toString(),
    );
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value?.toString() ?? '')?.toUtc();
  }

  static int _int(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static SyncState _syncState(dynamic value) {
    final text = value?.toString();
    return SyncState.values.firstWhere(
      (state) => state.name == text,
      orElse: () => SyncState.pending,
    );
  }
}

/// Common contract for all records that can be persisted and synchronized.
abstract interface class SyncableEntity {
  String get id;
  SyncMetadata get metadata;
}
