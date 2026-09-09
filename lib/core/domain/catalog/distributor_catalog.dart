/// Contract for workflows that need to register distributor catalog values.
///
/// Keeping this contract separate from presentation providers prevents product
/// and purchase workflows from depending on a concrete ChangeNotifier.
abstract interface class DistributorCatalog {
  void registerDistributorValue(String distributor);
}
