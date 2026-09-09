import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/domain/catalog/catalog_registrar.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

/// Presentation state coordinator for inventory products.
///
/// Persistence concerns stay outside the provider. The provider only owns
/// in-memory state, lookup operations, and coordination with the catalog.
class ProductProvider extends ChangeNotifier {
  final List<Product> _products = [];
  final CatalogRegistrar? _catalogRegistrar;

  ProductProvider({CatalogRegistrar? catalogRegistrar})
      : _catalogRegistrar = catalogRegistrar;

  List<Product> get products => List.unmodifiable(_products);

  /// Compatibility projection for legacy UI/import code.
  List<Map<String, dynamic>> get productMaps =>
      _products.map((product) => product.toMap()).toList(growable: false);

  Product? findById(String id) => _firstOrNull((product) => product.id == id);

  Product? findByBarcode(String barcode) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;
    return _firstOrNull((product) => product.barcode.trim() == normalized);
  }

  void addProduct(Product product) {
    final id = product.id.isEmpty ? IdGenerator.newId() : product.id;
    final normalized = product.copyWith(id: id, touchMetadata: false);

    _catalogRegistrar?.registerBrandValue(normalized.brand);
    _products.add(normalized);
    notifyListeners();
  }

  bool updateProduct(Product product) {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index < 0) return false;

    final current = _products[index];
    final updated = product.copyWith(
      metadata: current.metadata.touch(),
      touchMetadata: false,
    );

    _catalogRegistrar?.registerBrandValue(updated.brand);
    _products[index] = updated;
    notifyListeners();
    return true;
  }

  bool deleteProduct(String id) {
    final before = _products.length;
    _products.removeWhere((product) => product.id == id);
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
