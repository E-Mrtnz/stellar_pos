import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/product.dart';

class ProductProvider extends ChangeNotifier {
  final List<Product> _products = [];

  List<Product> get products => List.unmodifiable(_products);

  List<Map<String, dynamic>> get productMaps {
    return _products.map((product) => product.toMap()).toList();
  }

  Product? findById(String id) {
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }

    return null;
  }

  void addProduct(Product product) {
    final id = product.id.isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : product.id;

    final productToAdd = product.copyWith(id: id);

    _products.add(productToAdd);

    notifyListeners();
  }

  void updateProduct(Product product) {
    final index = _products.indexWhere((item) => item.id == product.id);

    if (index == -1) {
      return;
    }

    _products[index] = product;

    notifyListeners();
  }

  void deleteProduct(String id) {
    final index = _products.indexWhere((product) => product.id == id);

    if (index == -1) {
      return;
    }

    _products.removeAt(index);

    notifyListeners();
  }

  void clearProducts() {
    if (_products.isEmpty) {
      return;
    }

    _products.clear();

    notifyListeners();
  }
}
