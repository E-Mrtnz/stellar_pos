import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class ProductProvider extends ChangeNotifier {
  final List<Product> _products = [];

  List<Product> get products => List.unmodifiable(_products);

  List<Map<String, dynamic>> get productMaps =>
      _products.map((product) => product.toMap()).toList();

  Product? findById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  Product? findByBarcode(String barcode) {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) return null;
    for (final product in _products) {
      if (product.barcode.trim() == normalizedBarcode) return product;
    }
    return null;
  }

  void addProduct(Product product) {
    final id = product.id.isEmpty ? IdGenerator.newId() : product.id;
    final productToAdd = product.copyWith(id: id, touchMetadata: false);
    CatalogProvider.registerBrand(productToAdd.brand);
    _products.add(productToAdd);
    notifyListeners();
  }

  void updateProduct(Product product) {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index == -1) return;

    CatalogProvider.registerBrand(product.brand);
    _products[index] = product;
    notifyListeners();
  }

  void deleteProduct(String id) {
    final index = _products.indexWhere((product) => product.id == id);
    if (index == -1) return;
    _products.removeAt(index);
    notifyListeners();
  }

  void clearProducts() {
    if (_products.isEmpty) return;
    _products.clear();
    notifyListeners();
  }
}
