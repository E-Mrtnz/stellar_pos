import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/client.dart';

class CatalogProvider extends ChangeNotifier {
  final List<String> _tags = [];
  final List<String> _brands = [];
  final List<String> _distributors = [];
  final List<Client> _clients = [];

  List<String> get tags => _sorted(_tags);
  List<String> get brands => _sorted(_brands);
  List<String> get distributors => _sorted(_distributors);

  /// Backward-compatible alias while product forms are migrated.
  List<String> get departments => distributors;
  List<Client> get clients => List.unmodifiable(_clients);

  List<String> _sorted(List<String> values) {
    final sorted = List<String>.from(values);
    sorted.sort(_compareAlphabetically);
    return List.unmodifiable(sorted);
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
    _brands.add(value);
    notifyListeners();
  }

  void removeBrand(String brand) {
    _brands.removeWhere((item) => item.toLowerCase() == brand.toLowerCase());
    notifyListeners();
  }

  void addDistributor(String distributor) {
    final value = distributor.trim();
    if (value.isEmpty || _containsIgnoreCase(_distributors, value)) return;
    _distributors.add(value);
    notifyListeners();
  }

  void removeDistributor(String distributor) {
    _distributors.removeWhere((item) => item.toLowerCase() == distributor.toLowerCase());
    notifyListeners();
  }

  void addDepartment(String department) => addDistributor(department);
  void removeDepartment(String department) => removeDistributor(department);

  void addClient(Client client) {
    final name = client.name.trim();
    final phone = client.phone.trim();
    if (name.isEmpty || _containsClientName(name)) return;
    final id = client.id.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : client.id;
    _clients.add(client.copyWith(id: id, name: name, phone: phone));
    notifyListeners();
  }

  bool updateClient(Client client) {
    final index = _clients.indexWhere((item) => item.id == client.id);
    if (index < 0) return false;
    final name = client.name.trim();
    if (name.isEmpty) return false;
    final duplicate = _clients.any((item) => item.id != client.id && item.name.toLowerCase() == name.toLowerCase());
    if (duplicate) return false;
    _clients[index] = client.copyWith(name: name, phone: client.phone.trim());
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

  int _compareAlphabetically(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

  bool _containsIgnoreCase(List<String> values, String value) {
    final normalized = value.toLowerCase();
    return values.any((item) => item.toLowerCase() == normalized);
  }

  bool _containsClientName(String name) {
    final normalized = name.toLowerCase();
    return _clients.any((client) => client.name.toLowerCase() == normalized);
  }
}
