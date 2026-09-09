import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/providers/catalog_provider.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

class ProductProvider extends ChangeNotifier {
  final List<Product> _products = [];

  List<Product> get products => List.unmodifiable(_products);
  List<Map<String, dynamic>> get productMaps => _products.map((p) => p.toMap()).toList(growable: false);

  Product? findById(String id) => _firstOrNull((p) => p.id == id);

  Product? findByBarcode(String barcode) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;
    return _firstOrNull((p) => p.barcode.trim() == normalized);
  }

  void addProduct(Product product) {
    final id = product.id.isEmpty ? IdGenerator.newId() : product.id;
    final normalized = product.copyWith(id: id, touchMetadata: false);
    CatalogProvider.registerBrand(normalized.brand);
    _products.add(normalized);
    notifyListeners();
  }

  bool updateProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index < 0) return false;
    CatalogProvider.registerBrand(product.brand);
    _products[index] = product;
    notifyListeners();
    return true;
  }

  bool deleteProduct(String id) {
    final before = _products.length;
    _products.removeWhere((p) => p.id == id);
    if (before == _products.length) return false;
    notifyListeners();
    return true;
  }

  void clearProducts() {
    if (_products.isEmpty) return;
    _products.clear();
    notifyListeners();
  }

  Product? _firstOrNull(bool Function(Product) test) {
    for (final product in _products) {
      if (test(product)) return product;
    }
    return null;
  }
}
