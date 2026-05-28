/// Sliding-window per-process limiter on how often a single user can
/// submit reports.
///
/// This is *client-side defence in depth*. Real protection must come
/// from Firestore rules / Cloud Functions enforcing per-uid limits
/// server-side, but that's blocked on infra we don't own yet. Until
/// then, this stops the casual abuser from spam-reporting another
/// user out of the platform with a one-finger one-button mash.
///
/// The window is in-memory, so it resets when the app restarts.
/// That's deliberate — we don't want to leak the timestamps across
/// accounts or persist them through a reinstall.
///
/// Use [tryConsume] before performing the report; if it returns
/// false, do not submit and show the user [tooFastMessage].
class ReportRateLimiter {
  final int maxPerWindow;
  final Duration window;

  /// Injectable clock for deterministic tests.
  final DateTime Function() _now;

  final List<DateTime> _hits = [];

  ReportRateLimiter({
    this.maxPerWindow = 5,
    this.window = const Duration(hours: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Returns true if the call is allowed (and reserves a slot).
  /// Returns false if the caller is over the limit.
  bool tryConsume() {
    final cutoff = _now().subtract(window);
    _hits.removeWhere((t) => t.isBefore(cutoff));
    if (_hits.length >= maxPerWindow) return false;
    _hits.add(_now());
    return true;
  }

  /// Read-only view of the current window's used count. Useful for
  /// UI ("3/5 reports used") or tests.
  int get currentCount {
    final cutoff = _now().subtract(window);
    _hits.removeWhere((t) => t.isBefore(cutoff));
    return _hits.length;
  }

  /// User-facing message when [tryConsume] returns false.
  static const String tooFastMessage =
      'You have submitted several reports recently. Please wait an hour before reporting again.';
}
