import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/client.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class CatalogProvider extends ChangeNotifier {
  static final Set<String> _externalBrands = <String>{};

  final List<String> _tags = [];
  final List<String> _brands = [];
  final List<String> _distributors = [];
  final List<Client> _clients = [];

  List<String> get tags => _sorted(_tags);
  List<String> get brands => _sorted({..._brands, ..._externalBrands});
  List<String> get distributors => _sorted(_distributors);
  List<String> get departments => distributors;
  List<Client> get clients => List.unmodifiable(_clients);

  static void registerBrand(String brand) {
    final value = brand.trim();
    if (value.isNotEmpty) _externalBrands.add(value);
  }

  void addTag(String tag) {
    final value = tag.trim();
    if (value.isEmpty || _containsIgnoreCase(_tags, value)) return;
    _tags.add(value);
    notifyListeners();
  }

  void removeTag(String tag) {
    _tags.removeWhere((item) => item.toLowerCase() == tag.toLowerCase());
    notifyListeners();
  }

  void addBrand(String brand) {
    final value = brand.trim();
    if (value.isEmpty || _containsIgnoreCase(_brands, value)) return;
    _externalBrands.removeWhere(
      (item) => item.toLowerCase() == value.toLowerCase(),
    );
    _brands.add(value);
    notifyListeners();
  }

  void removeBrand(String brand) {
    _brands.removeWhere((item) => item.toLowerCase() == brand.toLowerCase());
    _externalBrands.removeWhere(
      (item) => item.toLowerCase() == brand.toLowerCase(),
    );
    notifyListeners();
  }

  void addDistributor(String distributor) {
    final value = distributor.trim();
    if (value.isEmpty || _containsIgnoreCase(_distributors, value)) return;
    _distributors.add(value);
    notifyListeners();
  }

  void removeDistributor(String distributor) {
    _distributors.removeWhere(
      (item) => item.toLowerCase() == distributor.toLowerCase(),
    );
    notifyListeners();
  }

  void addDepartment(String department) => addDistributor(department);
  void removeDepartment(String department) => removeDistributor(department);

  void addClient(Client client) {
    final name = client.name.trim();
    final phone = client.phone.trim();
    if (name.isEmpty || _containsClientName(name)) return;

    final id = client.id.isEmpty ? IdGenerator.newId() : client.id;
    _clients.add(
      client.copyWith(
        id: id,
        name: name,
        phone: phone,
        touchMetadata: false,
      ),
    );
    notifyListeners();
  }

  bool updateClient(Client client) {
    final index = _clients.indexWhere((item) => item.id == client.id);
    if (index < 0) return false;

    final name = client.name.trim();
    if (name.isEmpty) return false;
    final duplicate = _clients.any(
      (item) =>
          item.id != client.id && item.name.toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) return false;

    _clients[index] = client.copyWith(
      name: name,
      phone: client.phone.trim(),
    );
    notifyListeners();
    return true;
  }

  void removeClient(String clientId) {
    _clients.removeWhere((client) => client.id == clientId);
    notifyListeners();
  }

  Client? findClientById(String id) {
    for (final client in _clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  List<String> _sorted(Iterable<String> values) {
    final sorted = values.toList()..sort(_compareAlphabetically);
    return List.unmodifiable(sorted);
  }

  int _compareAlphabetically(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());

  bool _containsIgnoreCase(Iterable<String> values, String value) =>
      values.any((item) => item.toLowerCase() == value.toLowerCase());

  bool _containsClientName(String name) =>
      _clients.any((client) => client.name.toLowerCase() == name.toLowerCase());
}
