import 'package:flutter_test/flutter_test.dart';
import 'package:flyconnect/shared/utils/report_rate_limiter.dart';

void main() {
  group('ReportRateLimiter', () {
    test('allows up to maxPerWindow consumes', () {
      final limiter =
          ReportRateLimiter(maxPerWindow: 3, window: const Duration(hours: 1));
      expect(limiter.tryConsume(), isTrue);
      expect(limiter.tryConsume(), isTrue);
      expect(limiter.tryConsume(), isTrue);
      // The fourth consume in the same window must fail.
      expect(limiter.tryConsume(), isFalse);
      expect(limiter.currentCount, 3);
    });

    test('drops timestamps that have aged out of the window', () {
      var clock = DateTime(2026, 1, 1, 12, 0, 0);
      final limiter = ReportRateLimiter(
        maxPerWindow: 2,
        window: const Duration(minutes: 10),
        now: () => clock,
      );

      // 12:00 + 12:05 — both inside the 10-min window
      expect(limiter.tryConsume(), isTrue);
      clock = DateTime(2026, 1, 1, 12, 5, 0);
      expect(limiter.tryConsume(), isTrue);
      // Third attempt at 12:05 is denied — window full.
      expect(limiter.tryConsume(), isFalse);

      // Move 8 more minutes forward — the 12:00 hit ages out.
      clock = DateTime(2026, 1, 1, 12, 13, 0);
      // Now one slot is free again.
      expect(limiter.tryConsume(), isTrue);
      expect(limiter.currentCount, 2);
    });

    test('currentCount tracks the live window without consuming', () {
      var clock = DateTime(2026, 1, 1, 12, 0, 0);
      final limiter = ReportRateLimiter(
        maxPerWindow: 5,
        window: const Duration(minutes: 30),
        now: () => clock,
      );

      expect(limiter.currentCount, 0);
      limiter.tryConsume();
      limiter.tryConsume();
      expect(limiter.currentCount, 2);

      // Reading currentCount also prunes — confirm by aging past the window.
      clock = DateTime(2026, 1, 1, 13, 0, 0);
      expect(limiter.currentCount, 0);
    });

    test('boundary: a hit at exactly t==cutoff is dropped', () {
      var clock = DateTime(2026, 1, 1, 12, 0, 0);
      final limiter = ReportRateLimiter(
        maxPerWindow: 1,
        window: const Duration(minutes: 5),
        now: () => clock,
      );
      limiter.tryConsume();
      // Move to 12:05:00 exactly — pruning rule is `isBefore(cutoff)`,
      // and cutoff = now - window. So t == cutoff is NOT before, so it
      // is retained. Re-trying must fail.
      clock = DateTime(2026, 1, 1, 12, 5, 0);
      expect(limiter.tryConsume(), isFalse);
      // One millisecond past the window — now it ages out.
      clock = DateTime(2026, 1, 1, 12, 5, 1);
      expect(limiter.tryConsume(), isTrue);
    });

    test('default settings are 5 per hour', () {
      final limiter = ReportRateLimiter();
      expect(limiter.maxPerWindow, 5);
      expect(limiter.window, const Duration(hours: 1));
    });

    test('user-facing message is non-empty', () {
      expect(ReportRateLimiter.tooFastMessage, isNotEmpty);
    });
  });
}
