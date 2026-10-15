import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_sync_retry_policy.dart';

void main() {
  group('CloudSyncRetryPolicy', () {
    const policy = CloudSyncRetryPolicy();

    test('uses exponential delays for recorded failed attempts', () {
      expect(policy.delayForAttempt(1), const Duration(seconds: 2));
      expect(policy.delayForAttempt(2), const Duration(seconds: 4));
      expect(policy.delayForAttempt(3), const Duration(seconds: 8));
      expect(policy.delayForAttempt(4), const Duration(seconds: 16));
    });

    test('treats zero and negative attempt counts as the first attempt', () {
      expect(policy.delayForAttempt(0), const Duration(seconds: 2));
      expect(policy.delayForAttempt(-4), const Duration(seconds: 2));
    });

    test('caps delay at maximum', () {
      expect(policy.delayForAttempt(20), const Duration(minutes: 15));
    });

    test('stops retrying after configured maximum attempts', () {
      expect(policy.canRetry(0), isTrue);
      expect(policy.canRetry(7), isTrue);
      expect(policy.canRetry(8), isFalse);
      expect(policy.canRetry(80), isFalse);
    });

    test('supports custom limits', () {
      const custom = CloudSyncRetryPolicy(
        baseDelay: Duration(milliseconds: 250),
        maxDelay: Duration(seconds: 1),
        maxAttempts: 3,
      );

      expect(custom.delayForAttempt(1), const Duration(milliseconds: 250));
      expect(custom.delayForAttempt(2), const Duration(milliseconds: 500));
      expect(custom.delayForAttempt(3), const Duration(seconds: 1));
      expect(custom.canRetry(2), isTrue);
      expect(custom.canRetry(3), isFalse);
    });
  });
}
