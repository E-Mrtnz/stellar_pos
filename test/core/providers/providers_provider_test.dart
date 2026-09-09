import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/domain/catalog/distributor_catalog.dart';
import 'package:stellar_pos/core/providers/providers_provider.dart';

void main() {
  test('implements the distributor catalog contract', () {
    final provider = ProvidersProvider();
    final catalog = provider as DistributorCatalog;

    catalog.registerDistributorValue('Distribuidora A');
    catalog.registerDistributorValue(' distribuidora a ');

    expect(provider.distributors, ['Distribuidora A']);
  });
}
