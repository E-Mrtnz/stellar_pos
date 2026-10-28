import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_pos/core/cloud_sync_scheduler.dart';
import 'package:stellar_pos/core/cloud_sync_retry_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('scheduler is dormant until explicit opt-in start', () async {
    var runs = 0;
    final scheduler = CloudSyncScheduler(
      runBatch: () async { runs++; },
      interval: const Duration(days: 1),
      observeLifecycle: false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(runs, 0);
    expect(scheduler.isStarted, isFalse);
    scheduler.dispose();
  });

  test('start schedules a batch and stop prevents future scheduled work', () async {
    var runs = 0;
    final completed = Completer<void>();
    final scheduler = CloudSyncScheduler(
      runBatch: () async {
        runs++;
        if (!completed.isCompleted) completed.complete();
      },
      interval: const Duration(days: 1),
      observeLifecycle: false,
    );
    scheduler.start();
    await completed.future.timeout(const Duration(seconds: 2));
    expect(runs, 1);
    scheduler.stop();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(runs, 1);
    expect(scheduler.isStarted, isFalse);
  });

  test('failed batches schedule retry using exponential policy', () async {
    var runs = 0;
    final secondRun = Completer<void>();
    final scheduler = CloudSyncScheduler(
      runBatch: () async {
        runs++;
        if (runs == 1) throw StateError('temporary');
        if (!secondRun.isCompleted) secondRun.complete();
      },
      retryPolicy: const CloudSyncRetryPolicy(
        baseDelay: Duration(milliseconds: 5),
        maxDelay: Duration(milliseconds: 10),
        maxAttempts: 2,
      ),
      interval: const Duration(days: 1),
      observeLifecycle: false,
    );
    scheduler.start();
    await secondRun.future.timeout(const Duration(seconds: 2));
    expect(runs, 2);
    scheduler.stop();
  });
}
