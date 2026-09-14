import 'package:stellar_pos/core/models/sync_metadata.dart';

/// Persisted catalog state for provider-related values that are not entities.
class ProviderCatalogState implements SyncableEntity {
  @override
  final String id;
  final List<String> distributors;
  final List<String> tags;
  final List<String> brands;
  @override
  final SyncMetadata metadata;

  ProviderCatalogState({
    required this.id,
    required List<String> distributors,
    List<String> tags = const [],
    List<String> brands = const [],
    SyncMetadata? metadata,
  })  : distributors = List.unmodifiable(distributors),
        tags = List.unmodifiable(tags),
        brands = List.unmodifiable(brands),
        metadata = metadata ?? SyncMetadata.initial();

  Map<String, dynamic> toMap() => {
        'id': id,
        'distributors': distributors,
        'tags': tags,
        'brands': brands,
        'metadata': metadata.toMap(),
      };

  factory ProviderCatalogState.fromMap(Map<String, dynamic> map) =>
      ProviderCatalogState(
        id: map['id']?.toString() ?? 'provider_catalog',
        distributors: map['distributors'] is Iterable
            ? (map['distributors'] as Iterable)
                .map<String>((value) => value.toString())
                .toList()
            : const <String>[],
        tags: map['tags'] is Iterable
            ? (map['tags'] as Iterable)
                .map<String>((value) => value.toString())
                .toList()
            : const <String>[],
        brands: map['brands'] is Iterable
            ? (map['brands'] as Iterable)
                .map<String>((value) => value.toString())
                .toList()
            : const <String>[],
        metadata: map['metadata'] is Map
            ? SyncMetadata.fromMap(Map<String, dynamic>.from(map['metadata']))
            : SyncMetadata.initial(),
      );
}
