import 'package:stellar_pos/core/models/sync_metadata.dart';

class ProviderRoute implements SyncableEntity {
  @override
  final String id;
  final String type;
  final String distributorName;
  final List<int> weekdays;
  final int colorValue;
  @override
  final SyncMetadata metadata;

  ProviderRoute({
    required this.id,
    required this.type,
    required this.distributorName,
    required List<int> weekdays,
    required this.colorValue,
    SyncMetadata? metadata,
  })  : weekdays = List.unmodifiable(weekdays),
        metadata = metadata ?? SyncMetadata.initial();

  bool get isDeliveryPerson => type == 'Repartidor';
  bool hasWeekday(int weekday) => weekdays.contains(weekday);

  ProviderRoute copyWith({
    String? id,
    String? type,
    String? distributorName,
    List<int>? weekdays,
    int? colorValue,
    SyncMetadata? metadata,
    bool touchMetadata = true,
  }) => ProviderRoute(
        id: id ?? this.id,
        type: type ?? this.type,
        distributorName: distributorName ?? this.distributorName,
        weekdays: weekdays ?? this.weekdays,
        colorValue: colorValue ?? this.colorValue,
        metadata: metadata ??
            (touchMetadata ? this.metadata.touch() : this.metadata),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'distributorName': distributorName,
        'weekdays': weekdays,
        'colorValue': colorValue,
        'metadata': metadata.toMap(),
      };

  factory ProviderRoute.fromMap(Map<String, dynamic> map) => ProviderRoute(
        id: map['id']?.toString() ?? '',
        type: map['type']?.toString() ?? '',
        distributorName: map['distributorName']?.toString() ?? '',
        weekdays: _ints(map['weekdays']),
        colorValue: _toInt(map['colorValue']),
        metadata: map['metadata'] is Map
            ? SyncMetadata.fromMap(Map<String, dynamic>.from(map['metadata']))
            : SyncMetadata.initial(),
      );

  static List<int> _ints(dynamic value) => value is Iterable
      ? value.map(_toInt).toList()
      : const [];

  static int _toInt(dynamic value) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;
}
