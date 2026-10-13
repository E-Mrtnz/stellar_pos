import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_auth_gateway.dart';

void main() {
  group('FirebaseCloudAuth', () {
    test('can be constructed before Firebase initialization', () {
      final gateway = FirebaseCloudAuth();

      expect(gateway, isA<CloudAuthGateway>());
    });

    test('application identity does not imply store permissions', () {
      const user = CloudAuthUser(
        uid: 'firebase-user-123',
        email: 'cashier@example.com',
      );

      expect(user.uid, 'firebase-user-123');
      expect(user.email, 'cashier@example.com');
      expect(user.emailVerified, isFalse);
      // Store roles are intentionally not part of the authentication identity.
    });
  });
}
