import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/provider_person.dart';

class ProvidersProvider extends ChangeNotifier {
  final List<String> _distributors = [];
  final List<ProviderRoute> _routes = [];

  List<String> get distributors => List.unmodifiable(_distributors);

  List<ProviderRoute> get routes => List.unmodifiable(_routes);

  List<ProviderRoute> byType(String type) {
    return _routes.where((route) => route.type == type).toList();
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

    for (var i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      if (route.distributorName.toLowerCase() == oldName.toLowerCase()) {
        _routes[i] = route.copyWith(distributorName: value);
      }
    }

    notifyListeners();
    return true;
  }

  bool removeDistributor(String name) {
    final inUse = _routes.any(
      (route) =>
          route.distributorName.toLowerCase() == name.toLowerCase(),
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

  /// Creates a route only when that distributor/type combination does not
  /// already exist. A route owns all of its assigned weekdays.
  bool addRoute({
    required String type,
    required String distributorName,
    required List<int> weekdays,
    required int colorValue,
  }) {
    final normalizedName = distributorName.trim();
    final normalizedDays = _normalizeWeekdays(weekdays);
    if (normalizedName.isEmpty || normalizedDays.isEmpty) return false;

    final existingIndex = _routes.indexWhere(
      (route) =>
          route.type == type &&
          route.distributorName.toLowerCase() == normalizedName.toLowerCase(),
    );

    if (existingIndex >= 0) {
      final existing = _routes[existingIndex];
      final mergedDays = _normalizeWeekdays([
        ...existing.weekdays,
        ...normalizedDays,
      ]);
      _routes[existingIndex] = existing.copyWith(
        weekdays: mergedDays,
        colorValue: colorValue,
      );
    } else {
      _routes.add(
        ProviderRoute(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          type: type,
          distributorName: normalizedName,
          weekdays: List.unmodifiable(normalizedDays),
          colorValue: colorValue,
        ),
      );
    }

    notifyListeners();
    return true;
  }

  /// Replaces the complete weekday assignment of an existing route.
  bool updateRoute({
    required String id,
    required String type,
    required String distributorName,
    required List<int> weekdays,
    required int colorValue,
  }) {
    final index = _routes.indexWhere((route) => route.id == id);
    final normalizedName = distributorName.trim();
    final normalizedDays = _normalizeWeekdays(weekdays);
    if (index < 0 || normalizedName.isEmpty || normalizedDays.isEmpty) {
      return false;
    }

    final duplicate = _routes.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          entry.value.type == type &&
          entry.value.distributorName.toLowerCase() ==
              normalizedName.toLowerCase(),
    );
    if (duplicate) return false;

    _routes[index] = ProviderRoute(
      id: id,
      type: type,
      distributorName: normalizedName,
      weekdays: List.unmodifiable(normalizedDays),
      colorValue: colorValue,
    );

    notifyListeners();
    return true;
  }

  void removeRoute(String id) {
    _routes.removeWhere((route) => route.id == id);
    notifyListeners();
  }

  List<int> _normalizeWeekdays(List<int> weekdays) {
    return weekdays
        .where((day) => day >= 0 && day <= 6)
        .toSet()
        .toList()
      ..sort();
  }

  bool _containsIgnoreCase(List<String> values, String value) {
    final normalized = value.toLowerCase();
    return values.any((item) => item.toLowerCase() == normalized);
  }
}
