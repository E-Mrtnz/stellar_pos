import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/domain/catalog/distributor_catalog.dart';
import 'package:stellar_pos/core/domain/services/catalog_value_service.dart';
import 'package:stellar_pos/core/models/provider_person.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

/// Presentation state coordinator for distributors and delivery routes.
/// Catalog normalization rules are centralized in [CatalogValueService].
class ProvidersProvider extends ChangeNotifier implements DistributorCatalog {
  final CatalogValueService _service;
  final List<String> _distributors = [];
  final List<ProviderRoute> _routes = [];

  ProvidersProvider({CatalogValueService? service})
      : _service = service ?? const CatalogValueService();

  List<String> get distributors => _service.uniqueSorted(_distributors);
  List<ProviderRoute> get routes => List.unmodifiable(_routes);

  List<ProviderRoute> byType(String type) {
    return _routes.where((route) => route.type == type).toList();
  }

  @override
  void registerDistributorValue(String distributor) {
    addDistributor(distributor);
  }

  bool addDistributor(String name) {
    final value = _service.normalizeName(name);
    if (value.isEmpty || _service.containsIgnoreCase(_distributors, value)) {
      return false;
    }
    _distributors.add(value);
    notifyListeners();
    return true;
  }

  bool updateDistributor(String oldName, String newName) {
    final value = _service.normalizeName(newName);
    if (value.isEmpty) return false;

    final normalizedOld = _service.normalizeName(oldName).toLowerCase();
    final index = _distributors.indexWhere(
      (item) => _service.normalizeName(item).toLowerCase() == normalizedOld,
    );
    if (index < 0) return false;

    final duplicate = _distributors.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          _service.normalizeName(entry.value).toLowerCase() == value.toLowerCase(),
    );
    if (duplicate) return false;

    _distributors[index] = value;
    for (var i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      if (_service.normalizeName(route.distributorName).toLowerCase() ==
          normalizedOld) {
        _routes[i] = route.copyWith(distributorName: value);
      }
    }

    notifyListeners();
    return true;
  }

  bool removeDistributor(String name) {
    final normalized = _service.normalizeName(name).toLowerCase();
    final inUse = _routes.any(
      (route) =>
          _service.normalizeName(route.distributorName).toLowerCase() ==
          normalized,
    );
    if (inUse) return false;

    final before = _distributors.length;
    _distributors.removeWhere(
      (item) => _service.normalizeName(item).toLowerCase() == normalized,
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
    final normalizedName = _service.normalizeName(distributorName);
    final normalizedDays = _service.normalizeWeekdays(weekdays);
    if (normalizedName.isEmpty || normalizedDays.isEmpty) return false;

    final existingIndex = _routes.indexWhere(
      (route) =>
          route.type == type &&
          _service.normalizeName(route.distributorName).toLowerCase() ==
              normalizedName.toLowerCase(),
    );

    if (existingIndex >= 0) {
      final existing = _routes[existingIndex];
      final mergedDays = _service.normalizeWeekdays([
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
          id: IdGenerator.newId(),
          type: type,
          distributorName: normalizedName,
          weekdays: normalizedDays,
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
    final normalizedName = _service.normalizeName(distributorName);
    final normalizedDays = _service.normalizeWeekdays(weekdays);
    if (index < 0 || normalizedName.isEmpty || normalizedDays.isEmpty) {
      return false;
    }

    final duplicate = _routes.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          entry.value.type == type &&
          _service.normalizeName(entry.value.distributorName).toLowerCase() ==
              normalizedName.toLowerCase(),
    );
    if (duplicate) return false;

    _routes[index] = _routes[index].copyWith(
      type: type,
      distributorName: normalizedName,
      weekdays: normalizedDays,
      colorValue: colorValue,
    );

    notifyListeners();
    return true;
  }

  void removeRoute(String id) {
    _routes.removeWhere((route) => route.id == id);
    notifyListeners();
  }
}
