import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/domain/catalog/catalog_registrar.dart';
import 'package:stellar_pos/core/domain/repositories/repository.dart';
import 'package:stellar_pos/core/models/product.dart';
import 'package:stellar_pos/core/utils/id_generator.dart';

/// Presentation state coordinator for inventory products.
///
/// The provider owns UI state and coordinates persistence through the domain
/// repository contract. It does not know that the current implementation is
/// backed by Hive.
class ProductProvider extends ChangeNotifier {
  final List<Product> _products = [];
  final CatalogRegistrar? _catalogRegistrar;
  final Repository<Product>? _repository;
  Future<void>? _loadFuture;
  bool _loaded = false;

  ProductProvider({
    CatalogRegistrar? catalogRegistrar,
    Repository<Product>? repository,
  })  : _catalogRegistrar = catalogRegistrar,
        _repository = repository;

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

  /// Loads persisted products once. A provider without a repository remains
  /// purely in-memory, preserving compatibility with isolated UI tests.
  Future<void> load() {
    if (_loaded) return Future.value();
    final existing = _loadFuture;
    if (existing != null) return existing;

    final future = _loadFromRepository();
    _loadFuture = future;
    return future;
  }

  void addProduct(Product product) {
    final id = product.id.isEmpty ? IdGenerator.newId() : product.id;
    final normalized = product.copyWith(id: id, touchMetadata: false);

    _catalogRegistrar?.registerBrandValue(normalized.brand);
    _products.add(normalized);
    notifyListeners();
    _persist(() => _repository?.save(normalized));
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
    _persist(() => _repository?.save(updated));
    return true;
  }

  bool deleteProduct(String id) {
    final before = _products.length;
    _products.removeWhere((product) => product.id == id);
    if (before == _products.length) return false;
    notifyListeners();
    _persist(() => _repository?.delete(id));
    return true;
  }

  void clearProducts() {
    if (_products.isEmpty) return;
    final ids = _products.map((product) => product.id).toList(growable: false);
    _products.clear();
    notifyListeners();
    for (final id in ids) {
      _persist(() => _repository?.delete(id));
    }
  }

  Future<void> _loadFromRepository() async {
    final repository = _repository;
    if (repository == null) {
      _loaded = true;
      return;
    }

    final stored = await repository.getAll();
    final byId = <String, Product>{
      for (final product in _products) product.id: product,
    };
    for (final product in stored) {
      byId.putIfAbsent(product.id, () => product);
    }

    _products
      ..clear()
      ..addAll(byId.values);
    for (final product in stored) {
      _catalogRegistrar?.registerBrandValue(product.brand);
    }
    _loaded = true;
    if (stored.isNotEmpty) notifyListeners();
  }

  void _persist(Future<void>? Function()? operation) {
    final future = operation?.call();
    if (future != null) {
      unawaited(future.catchError((_) {}));
    }
  }

  Product? _firstOrNull(bool Function(Product) test) {
    for (final product in _products) {
      if (test(product)) return product;
    }
    return null;
  }
}
