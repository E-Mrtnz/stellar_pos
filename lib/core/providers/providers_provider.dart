import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/domain/services/catalog_value_service.dart';
import 'package:stellar_pos/core/models/provider_person.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

/// Presentation state coordinator for provider routes.
///
/// Distributor values are owned by [CatalogProvider]. This provider only
/// coordinates routes and exposes the catalog values to legacy provider UI.
class ProvidersProvider extends ChangeNotifier {
  final CatalogValueService _service;
  final List<ProviderRoute> _routes = [];
  final Repository<ProviderRoute>? _routeRepository;
  CatalogProvider? _catalogProvider;
  bool _loaded = false;
  Future<void>? _loadFuture;

  ProvidersProvider({
    CatalogValueService? service,
    CatalogProvider? catalogProvider,
    Repository<ProviderRoute>? routeRepository,
  })  : _service = service ?? const CatalogValueService(),
        _catalogProvider = catalogProvider,
        _routeRepository = routeRepository;

  List<String> get distributors =>
      _catalogProvider?.distributors ?? const <String>[];

  List<ProviderRoute> get routes => List.unmodifiable(_routes);

  void attachCatalog(CatalogProvider catalogProvider) {
    if (identical(_catalogProvider, catalogProvider)) return;
    _catalogProvider = catalogProvider;
    notifyListeners();
  }

  Future<void> load() {
    if (_loaded) return Future.value();
    final existing = _loadFuture;
    if (existing != null) return existing;
    final future = _loadRoutes();
    _loadFuture = future;
    return future;
  }

  List<ProviderRoute> byType(String type) {
    return _routes.where((route) => route.type == type).toList();
  }

  bool addDistributor(String name) {
    final catalog = _catalogProvider;
    if (catalog == null) return false;
    final added = catalog.addDistributor(name);
    if (added) notifyListeners();
    return added;
  }

  bool updateDistributor(String oldName, String newName) {
    final catalog = _catalogProvider;
    if (catalog == null) return false;
    final updated = catalog.updateDistributor(oldName, newName);
    if (!updated) return false;

    final normalizedOld = _service.normalizeName(oldName).toLowerCase();
    final normalizedNew = _service.normalizeName(newName);
    final changedRoutes = <ProviderRoute>[];
    for (var i = 0; i < _routes.length; i++) {
      final route = _routes[i];
      if (_service.normalizeName(route.distributorName).toLowerCase() == normalizedOld) {
        final updatedRoute = route.copyWith(distributorName: normalizedNew);
        _routes[i] = updatedRoute;
        changedRoutes.add(updatedRoute);
      }
    }
    notifyListeners();
    for (final route in changedRoutes) _persistRoute(route);
    return true;
  }

  bool removeDistributor(String name) {
    final catalog = _catalogProvider;
    if (catalog == null) return false;
    final normalized = _service.normalizeName(name).toLowerCase();
    final inUse = _routes.any(
      (route) =>
          _service.normalizeName(route.distributorName).toLowerCase() == normalized,
    );
    if (inUse) return false;
    final removed = catalog.removeDistributor(name);
    if (removed) notifyListeners();
    return removed;
  }

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

    late final ProviderRoute route;
    if (existingIndex >= 0) {
      final existing = _routes[existingIndex];
      route = existing.copyWith(
        weekdays: _service.normalizeWeekdays([
          ...existing.weekdays,
          ...normalizedDays,
        ]),
        colorValue: colorValue,
      );
      _routes[existingIndex] = route;
    } else {
      route = ProviderRoute(
        id: IdGenerator.newId(),
        type: type,
        distributorName: normalizedName,
        weekdays: normalizedDays,
        colorValue: colorValue,
      );
      _routes.add(route);
    }

    notifyListeners();
    _persistRoute(route);
    return true;
  }

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
    if (index < 0 || normalizedName.isEmpty || normalizedDays.isEmpty) return false;

    final duplicate = _routes.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          entry.value.type == type &&
          _service.normalizeName(entry.value.distributorName).toLowerCase() ==
              normalizedName.toLowerCase(),
    );
    if (duplicate) return false;

    final updated = _routes[index].copyWith(
      type: type,
      distributorName: normalizedName,
      weekdays: normalizedDays,
      colorValue: colorValue,
    );
    _routes[index] = updated;
    notifyListeners();
    _persistRoute(updated);
    return true;
  }

  void removeRoute(String id) {
    final index = _routes.indexWhere((route) => route.id == id);
    if (index < 0) return;
    _routes.removeAt(index);
    notifyListeners();
    unawaited(_routeRepository?.delete(id).catchError((_) {}));
  }

  Future<void> _loadRoutes() async {
    final storedRoutes = await _routeRepository?.getAll() ?? const <ProviderRoute>[];
    _routes
      ..clear()
      ..addAll(storedRoutes);
    _loaded = true;
    if (storedRoutes.isNotEmpty) notifyListeners();
  }

  void _persistRoute(ProviderRoute route) {
    unawaited(_routeRepository?.save(route).catchError((_) {}));
  }
}
