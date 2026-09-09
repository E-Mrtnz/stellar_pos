import 'package:stellar_pos/core/domain/catalog/distributor_catalog.dart';

/// Contract used by product workflows to register catalog values.
///
/// Presentation providers should depend on this small abstraction instead of
/// calling another provider statically.
abstract interface class CatalogRegistrar implements DistributorCatalog {
  void registerBrandValue(String brand);
  void registerCategoryValue(String category);
}
