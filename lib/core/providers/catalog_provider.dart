import 'package:flutter/foundation.dart';

class CatalogProvider extends ChangeNotifier {
  final List<String> _tags = [];
  final List<String> _departments = [];
  final List<String> _clients = [];

  List<String> get tags => List.unmodifiable(_tags);

  List<String> get departments => List.unmodifiable(_departments);

  List<String> get clients => List.unmodifiable(_clients);

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

  void addClient(String client) {
    final value = client.trim();

    if (value.isEmpty || _containsIgnoreCase(_clients, value)) {
      return;
    }

    _clients.add(value);
    notifyListeners();
  }

  void removeClient(String client) {
    _clients.removeWhere(
      (item) => item.toLowerCase() == client.toLowerCase(),
    );

    notifyListeners();
  }

  // ============================================================
  // UTILIDAD
  // ============================================================

  bool _containsIgnoreCase(List<String> values, String value) {
    final normalized = value.toLowerCase();

    return values.any((item) => item.toLowerCase() == normalized);
  }
}
