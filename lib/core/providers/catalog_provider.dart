import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/client.dart';

class CatalogProvider extends ChangeNotifier {
  final List<String> _tags = [];
  final List<String> _distributors = [];
  final List<Client> _clients = [];

  List<String> get tags => List.unmodifiable(_tags);

  List<String> get distributors => List.unmodifiable(_distributors);

  /// Backward-compatible alias while product forms are migrated.
  List<String> get departments => distributors;

  List<Client> get clients => List.unmodifiable(_clients);

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

  /// Backward-compatible API for existing product code.
  void addDepartment(String department) => addDistributor(department);

  /// Backward-compatible API for existing product code.
  void removeDepartment(String department) => removeDistributor(department);

  void addClient(Client client) {
    final name = client.name.trim();
    final phone = client.phone.trim();

    if (name.isEmpty || _containsClientName(name)) return;

    final id = client.id.isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : client.id;

    _clients.add(client.copyWith(id: id, name: name, phone: phone));
    notifyListeners();
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

  bool _containsIgnoreCase(List<String> values, String value) {
    final normalized = value.toLowerCase();
    return values.any((item) => item.toLowerCase() == normalized);
  }

  bool _containsClientName(String name) {
    final normalized = name.toLowerCase();
    return _clients.any((client) => client.name.toLowerCase() == normalized);
  }
}
