import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_firestore_repository.dart';

void main() {
  test('constructing the repository does not require Firebase initialization', () {
    expect(
      () => CloudFirestoreRepository(),
      returnsNormally,
    );
  });
}
