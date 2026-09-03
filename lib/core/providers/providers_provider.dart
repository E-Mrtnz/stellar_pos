import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/provider_person.dart';

class ProvidersProvider extends ChangeNotifier {
  final List<String> _distributors = [];
  final List<ProviderPerson> _people = [];

  List<String> get distributors => List.unmodifiable(_distributors);

  List<ProviderPerson> get people => List.unmodifiable(_people);

  List<ProviderPerson> byType(String type) {
    return _people.where((person) => person.type == type).toList();
  }

  bool addDistributor(String name) {
    final value = name.trim();
    if (value.isEmpty || _containsIgnoreCase(_distributors, value)) return false;
    _distributors.add(value);
    notifyListeners();
    return true;
  }

  bool updateDistributor(String oldName, String newName) {
    final value = newName.trim();
    if (value.isEmpty) return false;

    final index = _distributors.indexWhere(
      (item) => item.toLowerCase() == oldName.toLowerCase(),
    );
    if (index < 0) return false;

    final duplicate = _distributors.asMap().entries.any(
      (entry) =>
          entry.key != index && entry.value.toLowerCase() == value.toLowerCase(),
    );
    if (duplicate) return false;

    _distributors[index] = value;

    for (var i = 0; i < _people.length; i++) {
      final person = _people[i];
      if (person.name.toLowerCase() == oldName.toLowerCase()) {
        _people[i] = ProviderPerson(
          id: person.id,
          type: person.type,
          name: value,
          weekday: person.weekday,
          colorValue: person.colorValue,
        );
      }
    }

    notifyListeners();
    return true;
  }

  bool removeDistributor(String name) {
    final inUse = _people.any(
      (person) => person.name.toLowerCase() == name.toLowerCase(),
    );
    if (inUse) return false;

    final before = _distributors.length;
    _distributors.removeWhere(
      (item) => item.toLowerCase() == name.toLowerCase(),
    );

    if (_distributors.length == before) return false;

    notifyListeners();
    return true;
  }

  bool addPerson({
    required String type,
    required String name,
    required int weekday,
    required int colorValue,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return false;

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

  bool updatePerson({
    required String id,
    required String type,
    required String name,
    required int weekday,
    required int colorValue,
  }) {
    final index = _people.indexWhere((person) => person.id == id);
    if (index < 0) return false;

    _people[index] = ProviderPerson(
      id: id,
      type: type,
      name: name.trim(),
      weekday: weekday,
      colorValue: colorValue,
    );

    notifyListeners();
    return true;
  }

  void removePerson(String id) {
    _people.removeWhere((person) => person.id == id);
    notifyListeners();
  }

  bool _containsIgnoreCase(List<String> values, String value) {
    final normalized = value.toLowerCase();
    return values.any((item) => item.toLowerCase() == normalized);
  }
}
