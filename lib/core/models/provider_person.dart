class ProviderRoute {
  final String id;
  final String type;
  final String distributorName;
  final List<int> weekdays;
  final int colorValue;

  const ProviderRoute({
    required this.id,
    required this.type,
    required this.distributorName,
    required this.weekdays,
    required this.colorValue,
  });

  bool get isDeliveryPerson => type == 'Repartidor';

  bool hasWeekday(int weekday) => weekdays.contains(weekday);

  ProviderRoute copyWith({
    String? id,
    String? type,
    String? distributorName,
    List<int>? weekdays,
    int? colorValue,
  }) {
    return ProviderRoute(
      id: id ?? this.id,
      type: type ?? this.type,
      distributorName: distributorName ?? this.distributorName,
      weekdays: List.unmodifiable(weekdays ?? this.weekdays),
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
