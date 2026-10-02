import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_paths.dart';

void main() {
  test('creates a store-scoped document path', () {
    expect(CloudPaths.document('store-demo', 'phase1_test', 'record-1'), 'stores/store-demo/phase1_test/record-1');
  });
}
