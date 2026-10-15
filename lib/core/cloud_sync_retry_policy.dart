/// Deterministic retry scheduling for the future cloud sync worker.
///
/// The worker must classify errors before asking this policy. Permission,
/// validation, and authorization errors are permanent and should be blocked;
/// only transient failures should consume this schedule. No timer or network
/// work is performed by this class.
class CloudSyncRetryPolicy {
  const CloudSyncRetryPolicy({
    this.baseDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 15),
    this.maxAttempts = 8,
  })  : assert(baseDelay.inMilliseconds > 0),
        assert(maxDelay.inMilliseconds > 0),
        assert(maxAttempts > 0);

  final Duration baseDelay;
  final Duration maxDelay;
  final int maxAttempts;

  /// [attemptCount] is the number of failed attempts already recorded.
  ///
  /// Attempt 1 waits [baseDelay], attempt 2 waits twice that, and so on,
  /// capped at [maxDelay]. A zero or negative count is treated as attempt 1.
  Duration delayForAttempt(int attemptCount) {
    final exponent = (attemptCount <= 1 ? 0 : attemptCount - 1)
        .clamp(0, 30);
    var milliseconds = baseDelay.inMilliseconds;
    for (var i = 0; i < exponent; i++) {
      if (milliseconds >= maxDelay.inMilliseconds) {
        return maxDelay;
      }
      milliseconds *= 2;
    }
    return Duration(
      milliseconds: milliseconds.clamp(0, maxDelay.inMilliseconds),
    );
  }

  /// Whether another transient retry is allowed after [attemptCount] failures.
  bool canRetry(int attemptCount) => attemptCount < maxAttempts;
}
