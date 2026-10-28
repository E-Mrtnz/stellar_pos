import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_store_repository.dart';

void main() {
  test('constructing the store repository does not require Firebase startup', () {
    expect(() => CloudStoreRepository(), returnsNormally);
  });
}
