import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:stellar_pos/core/domain/catalog/catalog_registrar.dart';
import 'package:stellar_pos/core/domain/services/inventory_stock_service.dart';
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
  final Map<String, Product> _productsById = <String, Product>{};
  final Map<String, Product> _productsByBarcode = <String, Product>{};
  List<Map<String, dynamic>>? _productMapsCache;
  final CatalogRegistrar? _catalogRegistrar;
  final Repository<Product>? _repository;
  static const _inventoryStockService = InventoryStockService();
  Future<void>? _loadFuture;
  bool _loaded = false;

  bool get isLoading => !_loaded && _loadFuture != null;

  ProductProvider({
    CatalogRegistrar? catalogRegistrar,
    Repository<Product>? repository,
  }) : _catalogRegistrar = catalogRegistrar,
       _repository = repository;

  List<Product> get products => List.unmodifiable(_products);

  /// Compatibility projection for legacy UI/import code.
  List<Map<String, dynamic>> get productMaps =>
      _productMapsCache ??= _products
          .map((product) => product.toMap())
          .toList(growable: false);

  Product? findById(String id) => _productsById[id];

  Product? findByBarcode(String barcode) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;

    final exact = _productsByBarcode[normalized];
    if (exact != null) return exact;

    // Some cameras/readers add separators while the catalog stores the
    // barcode as plain digits. Only use this normalized fallback after the
    // exact lookup so existing matching behavior stays unchanged.
    final canonical = _canonicalBarcode(normalized);
    if (canonical.isEmpty) return null;

    for (final product in _products) {
      if (_canonicalBarcode(product.barcode) == canonical) {
        return product;
      }
    }
    return null;
  }

  /// Returns a product only when its barcode is already used by another
  /// product. Product names are intentionally not considered unique because
  /// the same product can exist in multiple presentations/units.
  Product? findDuplicateProduct(Product product, {String? excludingId}) {
    final excluded = excludingId ?? product.id;
    final barcode = product.barcode.trim();
    if (barcode.isEmpty) return null;

    final existing = _productsByBarcode[barcode];
    if (existing == null || existing.id == excluded) return null;
    return existing;
  }

  Future<void> load() {
    if (_loaded) return Future.value();
    final existing = _loadFuture;
    if (existing != null) return existing;

    final future = _loadFromRepository();
    _loadFuture = future;
    notifyListeners();
    return future;
  }

  bool addProduct(Product product) {
    final id = product.id.isEmpty ? IdGenerator.newId() : product.id;
    final normalized = product.copyWith(id: id, touchMetadata: false);
    if (findDuplicateProduct(normalized, excludingId: normalized.id) != null) {
      return false;
    }

    _catalogRegistrar?.registerBrandValue(normalized.brand);
    _catalogRegistrar?.registerCategoryValue(normalized.category);
    _catalogRegistrar?.registerDistributorValue(normalized.department);
    _products.add(normalized);
    _indexProduct(normalized);
    _invalidateProductMaps();
    notifyListeners();
    _persist(() => _repository?.save(normalized));
    return true;
  }

  bool updateProduct(Product product) {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index < 0) return false;
    if (findDuplicateProduct(product, excludingId: product.id) != null) {
      return false;
    }

    final current = _products[index];
    final updated = product.copyWith(
      metadata: current.metadata.touch(),
      touchMetadata: false,
    );

    _catalogRegistrar?.registerBrandValue(updated.brand);
    _catalogRegistrar?.registerCategoryValue(updated.category);
    _catalogRegistrar?.registerDistributorValue(updated.department);
    _products[index] = updated;
    _deindexProduct(current);
    _indexProduct(updated);
    _invalidateProductMaps();
    notifyListeners();
    _persist(() => _repository?.save(updated));
    return true;
  }

  bool updateStockToPhysical(String id, int physicalStock) {
    final index = _products.indexWhere((item) => item.id == id);
    if (index < 0) return false;
    final current = _products[index];
    final updated = _inventoryStockService.adjustToPhysical(
      current,
      physicalStock,
    );
    if (identical(updated, current)) return true;
    _products[index] = updated;
    _deindexProduct(current);
    _indexProduct(updated);
    _invalidateProductMaps();
    notifyListeners();
    _persist(() => _repository?.save(updated));
    return true;
  }

  /// Renames a catalog reference across every in-memory product and persists
  /// the affected products. This keeps product references valid when a
  /// category, brand or distributor is renamed from its catalog manager.
  int renameBrandReferences(String oldValue, String newValue) =>
      _renameReference(
        oldValue: oldValue,
        newValue: newValue,
        read: (product) => product.brand,
        write: (product) => product.copyWith(brand: newValue),
      );

  int renameCategoryReferences(String oldValue, String newValue) =>
      _renameReference(
        oldValue: oldValue,
        newValue: newValue,
        read: (product) => product.category,
        write: (product) => product.copyWith(category: newValue),
      );

  int renameDistributorReferences(String oldValue, String newValue) =>
      _renameReference(
        oldValue: oldValue,
        newValue: newValue,
        read: (product) => product.department,
        write: (product) => product.copyWith(department: newValue),
      );

  int _renameReference({
    required String oldValue,
    required String newValue,
    required String Function(Product product) read,
    required Product Function(Product product) write,
  }) {
    final oldNormalized = _normalizeCatalogValue(oldValue);
    final newTrimmed = newValue.trim();
    if (oldNormalized.isEmpty || newTrimmed.isEmpty) return 0;

    var changed = 0;
    final updatedProducts = <Product>[];
    for (var index = 0; index < _products.length; index++) {
      final product = _products[index];
      if (_normalizeCatalogValue(read(product)) != oldNormalized) continue;
      final updated = write(product);
      _products[index] = updated;
      _deindexProduct(product);
      _indexProduct(updated);
      updatedProducts.add(updated);
      changed++;
    }

    if (changed == 0) return 0;
    _invalidateProductMaps();
    notifyListeners();
    for (final product in updatedProducts) {
      _persist(() => _repository?.save(product));
    }
    return changed;
  }

  bool deleteProduct(String id) {
    final before = _products.length;
    final removed = _productsById[id];
    _products.removeWhere((product) => product.id == id);
    if (before == _products.length) return false;
    if (removed != null) _deindexProduct(removed);
    _invalidateProductMaps();
    notifyListeners();
    _persist(() => _repository?.delete(id));
    return true;
  }

  void clearProducts() {
    if (_products.isEmpty) return;
    final ids = _products.map((product) => product.id).toList(growable: false);
    _products.clear();
    _productsById.clear();
    _productsByBarcode.clear();
    _invalidateProductMaps();
    notifyListeners();
    for (final id in ids) {
      _persist(() => _repository?.delete(id));
    }
  }

  Future<void> refreshFromRepository() async {
    await _loadFromRepository();
    notifyListeners();
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
    _rebuildIndexes();
    _invalidateProductMaps();
    for (final product in stored) {
      _catalogRegistrar?.registerBrandValue(product.brand);
      _catalogRegistrar?.registerCategoryValue(product.category);
      _catalogRegistrar?.registerDistributorValue(product.department);
    }
    _loaded = true;
    notifyListeners();
  }

  void _rebuildIndexes() {
    _productsById.clear();
    _productsByBarcode.clear();
    for (final product in _products) {
      _indexProduct(product);
    }
  }

  void _indexProduct(Product product) {
    if (product.id.isNotEmpty) {
      _productsById[product.id] = product;
    }
    final barcode = product.barcode.trim();
    if (barcode.isNotEmpty) {
      _productsByBarcode[barcode] = product;
    }
  }

  void _deindexProduct(Product product) {
    if (product.id.isNotEmpty &&
        identical(_productsById[product.id], product)) {
      _productsById.remove(product.id);
    }
    final barcode = product.barcode.trim();
    if (barcode.isNotEmpty &&
        identical(_productsByBarcode[barcode], product)) {
      _productsByBarcode.remove(barcode);
    }
  }

  void _invalidateProductMaps() {
    _productMapsCache = null;
  }

  void _persist(Future<void>? Function()? operation) {
    final future = operation?.call();
    if (future != null) {
      unawaited(future.catchError((_) {}));
    }
  }

  String _canonicalBarcode(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty && digits.length == trimmed.replaceAll(RegExp(r'[\s-]'), '').length) {
      return digits.replaceFirst(RegExp(r'^0+(?=\\d)'), '');
    }
    return trimmed.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  String _normalizeCatalogValue(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
