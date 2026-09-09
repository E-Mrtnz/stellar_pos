/// Contract used by product workflows to register catalog values.
///
/// Presentation providers should depend on this small abstraction instead of
/// calling another provider statically.
abstract interface class CatalogRegistrar {
  void registerBrandValue(String brand);
  void registerCategoryValue(String category);
}
