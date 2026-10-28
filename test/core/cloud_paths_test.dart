import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_paths.dart';

void main() {
  group('CloudPaths.document', () {
    test('builds a path scoped under the requested store', () {
      expect(
        CloudPaths.document('store-123', 'products', 'product-456'),
        'stores/store-123/products/product-456',
      );
    });

    test('rejects an empty store ID', () {
      expect(
        () => CloudPaths.document('', 'products', 'product-456'),
        throwsArgumentError,
      );
    });

    test('rejects whitespace-only path segments', () {
      expect(
        () => CloudPaths.document('store-123', '  ', 'product-456'),
        throwsArgumentError,
      );
    });

    test('rejects slashes in any path segment', () {
      expect(
        () => CloudPaths.document('store/other', 'products', 'product-456'),
        throwsArgumentError,
      );
      expect(
        () => CloudPaths.document('store-123', 'products/nested', 'product-456'),
        throwsArgumentError,
      );
      expect(
        () => CloudPaths.document('store-123', 'products', 'product/other'),
        throwsArgumentError,
      );
    });
  });
}
