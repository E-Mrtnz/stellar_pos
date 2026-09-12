import 'package:stellar_pos/core/models/sync_metadata.dart';

class ClientGroup implements SyncableEntity {
  @override
  final String id;
  final String name;
  final List<String> clientIds;
  @override
  final SyncMetadata metadata;

  ClientGroup({
    required this.id,
    required this.name,
    required List<String> clientIds,
    SyncMetadata? metadata,
  })  : clientIds = List.unmodifiable(clientIds),
        metadata = metadata ?? SyncMetadata.initial();

  ClientGroup copyWith({
    String? id,
    String? name,
    List<String>? clientIds,
    SyncMetadata? metadata,
    bool touchMetadata = true,
  }) => ClientGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        clientIds: clientIds ?? this.clientIds,
        metadata: metadata ??
            (touchMetadata ? this.metadata.touch() : this.metadata),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'clientIds': clientIds,
        'metadata': metadata.toMap(),
      };

  factory ClientGroup.fromMap(Map<String, dynamic> map) => ClientGroup(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        clientIds: _clientIds(map['clientIds']),
        metadata: _metadata(map['metadata']),
      );

  static List<String> _clientIds(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static SyncMetadata _metadata(dynamic value) => value is Map
      ? SyncMetadata.fromMap(Map<String, dynamic>.from(value))
      : SyncMetadata.initial();
}
