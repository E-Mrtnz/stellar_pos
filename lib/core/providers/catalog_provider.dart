import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/app/app_dependencies.dart';
import 'package:stellar_pos/core/data/repositories/client_repository.dart';
import 'package:stellar_pos/core/domain/catalog/catalog_registrar.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/domain/services/catalog_value_service.dart';
import 'package:stellar_pos/core/models/client.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

/// Presentation state coordinator for catalog values and clients.
/// Pure normalization/comparison rules live in [CatalogValueService].
class CatalogProvider extends ChangeNotifier implements CatalogRegistrar {
  static final Set<String> _externalBrands = <String>{};

  final CatalogValueService _service;
  final Repository<Client>? _clientRepository;
  final List<String> _tags = [];
  final List<String> _brands = [];
  final List<String> _distributors = [];
  final List<Client> _clients = [];
  Future<void>? _loadClientsFuture;
  bool _clientsLoaded = false;

  CatalogProvider({
    CatalogValueService? service,
    Repository<Client>? clientRepository,
  })  : _service = service ?? AppDependencies.catalogValue,
        _clientRepository = clientRepository;

  List<String> get tags => _service.uniqueSorted(_tags);
  List<String> get brands =>
      _service.uniqueSorted({..._brands, ..._externalBrands});
  List<String> get distributors => _service.uniqueSorted(_distributors);
  List<String> get departments => distributors;
  List<Client> get clients => List.unmodifiable(_clients);

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

  static void registerBrand(String brand) {
    final value = brand.trim();
    if (value.isNotEmpty) _externalBrands.add(value);
  }

  void addTag(String tag) {
    final value = _service.normalizeName(tag);
    if (value.isEmpty || _service.containsIgnoreCase(_tags, value)) return;
    _tags.add(value);
    notifyListeners();
  }

  void removeTag(String tag) {
    _tags.removeWhere((item) =>
        _service.normalizeName(item).toLowerCase() ==
        _service.normalizeName(tag).toLowerCase());
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

  void addDistributor(String distributor) {
    final value = _service.normalizeName(distributor);
    if (value.isEmpty || _service.containsIgnoreCase(_distributors, value)) {
      return;
    }
    _distributors.add(value);
    notifyListeners();
  }

  void removeDistributor(String distributor) {
    final normalized = _service.normalizeName(distributor).toLowerCase();
    _distributors.removeWhere((item) =>
        _service.normalizeName(item).toLowerCase() == normalized);
    notifyListeners();
  }

  void addDepartment(String department) => addDistributor(department);
  void removeDepartment(String department) => removeDistributor(department);

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
    unawaited(_clientRepository?.save(normalized));
  }

  bool updateClient(Client client) {
    final index = _clients.indexWhere((item) => item.id == client.id);
    if (index < 0) return false;
    final name = _service.normalizeName(client.name);
    if (name.isEmpty) return false;
    final duplicate = _clients.any((item) =>
        item.id != client.id && item.name.toLowerCase() == name.toLowerCase());
    if (duplicate) return false;
    final updated = client.copyWith(
      name: name,
      phone: client.phone.trim(),
    );
    _clients[index] = updated;
    notifyListeners();
    unawaited(_clientRepository?.save(updated));
    return true;
  }

  void removeClient(String clientId) {
    final before = _clients.length;
    _clients.removeWhere((client) => client.id == clientId);
    if (before == _clients.length) return;
    notifyListeners();
    unawaited(_clientRepository?.delete(clientId));
  }

  Client? findClientById(String id) {
    for (final client in _clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  Future<void> _loadClientsFromRepository() async {
    final repository = _clientRepository;
    if (repository != null) {
      final stored = await repository.getAll();
      final byId = <String, Client>{
        for (final client in _clients) client.id: client,
      };
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

  bool _containsClientName(String name) => _clients.any(
        (client) => client.name.toLowerCase() == name.toLowerCase(),
      );
}
