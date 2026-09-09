import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/data/repositories/client_repository.dart';
import 'package:stellar_pos/core/data/repositories/provider_catalog_repository.dart';
import 'package:stellar_pos/core/domain/catalog/catalog_registrar.dart';
import 'package:stellar_pos/core/domain/catalog/distributor_catalog.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/domain/services/catalog_value_service.dart';
import 'package:stellar_pos/core/models/client.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/models/provider_catalog_state.dart';
import 'package:stellar_pos/core/models/provider_person.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

/// Presentation state coordinator for catalog values and clients.
///
/// Categories, brands and distributors have one source of truth here. The
/// catalog is persisted as a single state record so every UI that needs a
/// distributor reads the same collection.
class CatalogProvider extends ChangeNotifier
    implements CatalogRegistrar, DistributorCatalog {
  static final Set<String> _externalBrands = <String>{};
  static const _catalogStateId = 'catalog';
  static const _legacyCatalogStateId = 'provider_catalog';

  final CatalogValueService _service;
  final Repository<Client>? _clientRepository;
  final Repository<Product>? _productRepository;
  final Repository<ProviderRoute>? _routeRepository;
  final Repository<ProviderCatalogState>? _catalogRepository;
  final List<String> _tags = [];
  final List<String> _brands = [];
  final List<String> _distributors = [];
  final List<Client> _clients = [];
  Future<void>? _loadClientsFuture;
  Future<void>? _loadCatalogFuture;
  bool _clientsLoaded = false;
  bool _catalogLoaded = false;

  CatalogProvider({
    CatalogValueService? service,
    Repository<Client>? clientRepository,
    Repository<Product>? productRepository,
    Repository<ProviderRoute>? routeRepository,
    Repository<ProviderCatalogState>? catalogRepository,
  })  : _service = service ?? AppDependencies.catalogValue,
        _clientRepository = clientRepository,
        _productRepository = productRepository,
        _routeRepository = routeRepository,
        _catalogRepository = catalogRepository ?? ProviderCatalogRepository();

  List<String> get tags => _service.uniqueSorted(_tags);
  List<String> get brands =>
      _service.uniqueSorted({..._brands, ..._externalBrands});
  List<String> get distributors => _service.uniqueSorted(_distributors);
  List<String> get departments => distributors;
  List<Client> get clients => List.unmodifiable(_clients);

  Future<void> load() {
    if (_catalogLoaded) return Future.value();
    final existing = _loadCatalogFuture;
    if (existing != null) return existing;
    final future = _loadCatalogFromRepository();
    _loadCatalogFuture = future;
    return future;
  }

  Future<void> loadClients() {
    if (_clientsLoaded) return Future.value();
    final existing = _loadClientsFuture;
    if (existing != null) return existing;
    final future = _loadClientsFromRepository();
    _loadClientsFuture = future;
    return future;
  }

  @override
  void registerBrandValue(String brand) {
    final value = brand.trim();
    if (value.isEmpty || _service.containsIgnoreCase(_brands, value)) return;
    if (_service.containsIgnoreCase(_externalBrands, value)) return;
    _externalBrands.add(value);
    notifyListeners();
  }

  @override
  void registerCategoryValue(String category) {
    final value = _service.normalizeName(category);
    if (value.isEmpty || _service.containsIgnoreCase(_tags, value)) return;
    _tags.add(value);
    _persistCatalog();
    notifyListeners();
  }

  @override
  void registerDistributorValue(String distributor) {
    final value = _service.normalizeName(distributor);
    if (value.isEmpty || _service.containsIgnoreCase(_distributors, value)) {
      return;
    }
    _distributors.add(value);
    _persistCatalog();
    notifyListeners();
  }

  static void registerBrand(String brand) {
    final value = brand.trim();
    if (value.isNotEmpty) _externalBrands.add(value);
  }

  void addTag(String tag) {
    final value = _service.normalizeName(tag);
    if (value.isEmpty || _service.containsIgnoreCase(_tags, value)) return;
    _tags.add(value);
    _persistCatalog();
    notifyListeners();
  }

  void removeTag(String tag) {
    _tags.removeWhere((item) =>
        _service.normalizeName(item).toLowerCase() ==
        _service.normalizeName(tag).toLowerCase());
    _persistCatalog();
    notifyListeners();
  }

  void addBrand(String brand) {
    final value = _service.normalizeName(brand);
    if (value.isEmpty || _service.containsIgnoreCase(_brands, value)) return;
    _externalBrands.removeWhere((item) =>
        _service.normalizeName(item).toLowerCase() == value.toLowerCase());
    _brands.add(value);
    notifyListeners();
  }

  void removeBrand(String brand) {
    final normalized = _service.normalizeName(brand).toLowerCase();
    _brands.removeWhere((item) =>
        _service.normalizeName(item).toLowerCase() == normalized);
    _externalBrands.removeWhere((item) =>
        _service.normalizeName(item).toLowerCase() == normalized);
    notifyListeners();
  }

  bool addDistributor(String distributor) {
    final value = _service.normalizeName(distributor);
    if (value.isEmpty || _service.containsIgnoreCase(_distributors, value)) {
      return false;
    }
    _distributors.add(value);
    _persistCatalog();
    notifyListeners();
    return true;
  }

  bool updateDistributor(String oldDistributor, String newDistributor) {
    final oldValue = _service.normalizeName(oldDistributor);
    final newValue = _service.normalizeName(newDistributor);
    if (oldValue.isEmpty || newValue.isEmpty) return false;

    final index = _distributors.indexWhere(
      (item) =>
          _service.normalizeName(item).toLowerCase() == oldValue.toLowerCase(),
    );
    if (index < 0) return false;

    final duplicate = _distributors.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          _service.normalizeName(entry.value).toLowerCase() ==
              newValue.toLowerCase(),
    );
    if (duplicate) return false;

    _distributors[index] = newValue;
    _persistCatalog();
    notifyListeners();
    return true;
  }

  bool removeDistributor(String distributor) {
    final normalized = _service.normalizeName(distributor).toLowerCase();
    final before = _distributors.length;
    _distributors.removeWhere(
      (item) => _service.normalizeName(item).toLowerCase() == normalized,
    );
    if (_distributors.length == before) return false;
    _persistCatalog();
    notifyListeners();
    return true;
  }

  void addDepartment(String department) {
    addDistributor(department);
  }

  void removeDepartment(String department) {
    removeDistributor(department);
  }

  void addClient(Client client) {
    final name = _service.normalizeName(client.name);
    final phone = client.phone.trim();
    if (name.isEmpty || _containsClientName(name)) return;
    final id = client.id.isEmpty ? IdGenerator.newId() : client.id;
    final normalized = client.copyWith(
      id: id,
      name: name,
      phone: phone,
      touchMetadata: false,
    );
    _clients.add(normalized);
    notifyListeners();
    _persist(() => _clientRepository?.save(normalized));
  }

  bool updateClient(Client client) {
    final index = _clients.indexWhere((item) => item.id == client.id);
    if (index < 0) return false;
    final name = _service.normalizeName(client.name);
    if (name.isEmpty) return false;
    final duplicate = _clients.any((item) =>
        item.id != client.id && item.name.toLowerCase() == name.toLowerCase());
    if (duplicate) return false;
    final updated = client.copyWith(name: name, phone: client.phone.trim());
    _clients[index] = updated;
    notifyListeners();
    _persist(() => _clientRepository?.save(updated));
    return true;
  }

  void removeClient(String clientId) {
    final before = _clients.length;
    _clients.removeWhere((client) => client.id == clientId);
    if (before == _clients.length) return;
    notifyListeners();
    _persist(() => _clientRepository?.delete(clientId));
  }

  Client? findClientById(String id) {
    for (final client in _clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  Future<void> _loadCatalogFromRepository() async {
    final repository = _catalogRepository;
    if (repository == null) {
      _catalogLoaded = true;
      return;
    }

    final current = await repository.getById(_catalogStateId);
    final legacy = await repository.getById(_legacyCatalogStateId);
    final products =
        await _productRepository?.getAll() ?? const <Product>[];
    final routes =
        await _routeRepository?.getAll() ?? const <ProviderRoute>[];

    final mergedTags = <String>[];
    final mergedDistributors = <String>[];

    void addUnique(List<String> target, String raw) {
      final value = _service.normalizeName(raw);
      if (value.isNotEmpty && !_service.containsIgnoreCase(target, value)) {
        target.add(value);
      }
    }

    void mergeState(ProviderCatalogState? state) {
      if (state == null) return;
      for (final tag in state.tags) addUnique(mergedTags, tag);
      for (final distributor in state.distributors) {
        addUnique(mergedDistributors, distributor);
      }
    }

    mergeState(current);
    mergeState(legacy);

    // Recover distributors that were already persisted as part of routes.
    for (final route in routes) {
      addUnique(mergedDistributors, route.distributorName);
    }

    // Recover distributors from existing products as an additional migration
    // path for versions that never persisted the distributor catalog.
    for (final product in products) {
      addUnique(mergedDistributors, product.department);
    }

    _tags
      ..clear()
      ..addAll(mergedTags);
    _distributors
      ..clear()
      ..addAll(mergedDistributors);

    _catalogLoaded = true;

    if (legacy != null || routes.isNotEmpty || products.isNotEmpty) {
      _persistCatalog();
    }

    if (current != null || legacy != null || routes.isNotEmpty || products.isNotEmpty) {
      notifyListeners();
    }
  }

  void _persistCatalog() {
    final repository = _catalogRepository;
    if (repository == null) return;
    final state = ProviderCatalogState(
      id: _catalogStateId,
      distributors: _distributors,
      tags: _tags,
    );
    unawaited(repository.save(state).catchError((_) {}));
  }

  Future<void> _loadClientsFromRepository() async {
    final repository = _clientRepository;
    if (repository != null) {
      final stored = await repository.getAll();
      final byId = <String, Client>{for (final client in _clients) client.id: client};
      for (final client in stored) {
        byId.putIfAbsent(client.id, () => client);
      }
      _clients
        ..clear()
        ..addAll(byId.values);
      if (stored.isNotEmpty) notifyListeners();
    }
    _clientsLoaded = true;
  }

  void _persist(Future<void>? Function()? operation) {
    final future = operation?.call();
    if (future != null) unawaited(future.catchError((_) {}));
  }

  bool _containsClientName(String name) =>
      _clients.any((client) => client.name.toLowerCase() == name.toLowerCase());
}
