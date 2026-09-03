import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/provider_person.dart';

class ProvidersProvider extends ChangeNotifier {
  final List<ProviderPerson> _people = [];

  List<ProviderPerson> get people => List.unmodifiable(_people);

  List<ProviderPerson> byType(String type) {
    return _people.where((person) => person.type == type).toList();
  }

  bool addPerson({
    required String type,
    required String name,
    required int weekday,
    required int colorValue,
  }) {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) return false;

    final exists = _people.any(
      (person) =>
          person.type == type &&
          person.name.toLowerCase() == normalizedName.toLowerCase(),
    );

    if (exists) return false;

    _people.add(
      ProviderPerson(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: type,
        name: normalizedName,
        weekday: weekday,
        colorValue: colorValue,
      ),
    );

    notifyListeners();
    return true;
  }

  void removePerson(String id) {
    _people.removeWhere((person) => person.id == id);
    notifyListeners();
  }
}
