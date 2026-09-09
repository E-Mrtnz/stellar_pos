import 'package:flutter_test/flutter_test.dart';

import 'package:stellar_pos/core/providers/providers_provider.dart';

void main() {
  test('registerDistributorValue uses the provider catalog workflow', () {
    final provider = ProvidersProvider();

    provider.registerDistributorValue('  Distribuidora Norte  ');

    expect(provider.distributors, contains('Distribuidora Norte'));
  });

  test('does not register duplicate distributor values ignoring case', () {
    final provider = ProvidersProvider();

    provider.registerDistributorValue('Distribuidora Norte');
    provider.registerDistributorValue('distribuidora norte');

    expect(provider.distributors, ['Distribuidora Norte']);
  });
}
