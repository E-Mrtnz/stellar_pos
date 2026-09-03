class ProviderPerson {
  final String id;
  final String type;
  final String name;
  final int weekday;
  final int colorValue;

  const ProviderPerson({
    required this.id,
    required this.type,
    required this.name,
    required this.weekday,
    required this.colorValue,
  });

  bool get isDeliveryPerson => type == 'Repartidor';
}
