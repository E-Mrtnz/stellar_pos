import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Persisted catalog state for provider-related values that are not entities.
class ProviderCatalogState implements SyncableEntity {
  @override
  final String id;
  final List<String> distributors;
  final List<String> tags;
  @override
  final SyncMetadata metadata;

  ProviderCatalogState({
    required this.id,
    required List<String> distributors,
    List<String> tags = const [],
    SyncMetadata? metadata,
  })  : distributors = List.unmodifiable(distributors),
        tags = List.unmodifiable(tags),
        metadata = metadata ?? SyncMetadata.initial();

  Map<String, dynamic> toMap() => {
        'id': id,
        'distributors': distributors,
        'tags': tags,
        'metadata': metadata.toMap(),
      };

  factory ProviderCatalogState.fromMap(Map<String, dynamic> map) =>
      ProviderCatalogState(
        id: map['id']?.toString() ?? 'provider_catalog',
        distributors: map['distributors'] is Iterable
            ? map['distributors'].map((value) => value.toString()).toList()
            : const [],
        tags: map['tags'] is Iterable
            ? map['tags'].map((value) => value.toString()).toList()
            : const [],
        metadata: map['metadata'] is Map
            ? SyncMetadata.fromMap(Map<String, dynamic>.from(map['metadata']))
            : SyncMetadata.initial(),
      );
}
