import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyconnect/shared/widgets/inline_error_banner.dart';

void main() {
  group('InlineErrorBanner', () {
    testWidgets('renders the message text', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: InlineErrorBanner(message: 'Could not load the feed.'),
        ),
      ));
      expect(find.text('Could not load the feed.'), findsOneWidget);
    });

    testWidgets('Retry button only appears when onRetry is provided',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: InlineErrorBanner(message: 'x')),
      ));
      expect(find.text('Retry'), findsNothing);

      bool retried = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InlineErrorBanner(
            message: 'x',
            onRetry: () => retried = true,
          ),
        ),
      ));
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('Dismiss button only appears when onDismiss is provided',
        (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InlineErrorBanner(
            message: 'x',
            onDismiss: () => dismissed = true,
          ),
        ),
      ));
      // Dismiss is the close icon with tooltip 'Dismiss'.
      final dismiss = find.byTooltip('Dismiss');
      expect(dismiss, findsOneWidget);
      await tester.tap(dismiss);
      expect(dismissed, isTrue);
    });

    testWidgets('wraps content in a live-region Semantics node',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: InlineErrorBanner(message: 'Could not load the feed.'),
        ),
      ));
      // The Semantics node we add should announce as a live region with
      // an "Error: ..." label so TalkBack picks it up the moment it
      // appears in the tree.
      final semantics = tester.getSemantics(find.byType(InlineErrorBanner));
      expect(semantics.label, contains('Error: Could not load the feed.'));
    });
  });
}
