import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/client.dart';

class CatalogProvider extends ChangeNotifier {
  final List<String> _tags = [];
  final List<String> _departments = [];
  final List<Client> _clients = [];

  List<String> get tags => List.unmodifiable(_tags);

  List<String> get departments => List.unmodifiable(_departments);

  List<Client> get clients => List.unmodifiable(_clients);

  // ============================================================
  // ETIQUETAS
  // ============================================================

  void addTag(String tag) {
    final value = tag.trim();

    if (value.isEmpty || _containsIgnoreCase(_tags, value)) {
      return;
    }

    _tags.add(value);
    notifyListeners();
  }

  void removeTag(String tag) {
    _tags.removeWhere(
      (item) => item.toLowerCase() == tag.toLowerCase(),
    );

    notifyListeners();
  }

  // ============================================================
  // DEPARTAMENTOS
  // ============================================================

  void addDepartment(String department) {
    final value = department.trim();

    if (value.isEmpty || _containsIgnoreCase(_departments, value)) {
      return;
    }

    _departments.add(value);
    notifyListeners();
  }

  void removeDepartment(String department) {
    _departments.removeWhere(
      (item) => item.toLowerCase() == department.toLowerCase(),
    );

    notifyListeners();
  }

  // ============================================================
  // CLIENTES
  // ============================================================

  void addClient(Client client) {
    final name = client.name.trim();
    final phone = client.phone.trim();

    if (name.isEmpty) {
      return;
    }

    if (_containsClientName(name)) {
      return;
    }

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
      if (client.id == id) {
        return client;
      }
    }

    return null;
  }

  // ============================================================
  // UTILIDADES
  // ============================================================

  bool _containsIgnoreCase(List<String> values, String value) {
    final normalized = value.toLowerCase();

    return values.any((item) => item.toLowerCase() == normalized);
  }

  bool _containsClientName(String name) {
    final normalized = name.toLowerCase();

    return _clients.any(
      (client) => client.name.toLowerCase() == normalized,
    );
  }
}
