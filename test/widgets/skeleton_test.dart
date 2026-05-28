import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyconnect/shared/widgets/skeleton.dart';

void main() {
  group('Skeleton', () {
    testWidgets('renders with provided dimensions', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Skeleton(width: 200, height: 40, radius: 8),
        ),
      ));
      final box = tester.getSize(find.byType(Skeleton));
      expect(box.width, 200);
      expect(box.height, 40);
    });

    testWidgets('circle variant produces a square', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Skeleton.circle(size: 48)),
      ));
      final box = tester.getSize(find.byType(Skeleton));
      expect(box.width, 48);
      expect(box.height, 48);
    });

    testWidgets('animation runs without throwing', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Skeleton(width: 100, height: 10)),
      ));
      // Pump several frames to drive the animation controller; if the
      // setState loop ever errors out this will throw.
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(Skeleton), findsOneWidget);
    });
  });

  group('FeedPostSkeleton', () {
    testWidgets('builds and contains multiple Skeleton primitives',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: FeedPostSkeleton()),
      ));
      // A feed post skeleton should contain at least 6 Skeleton blocks:
      // avatar circle + 2 header lines + image + 2 caption lines + 3 actions.
      expect(find.byType(Skeleton), findsAtLeastNWidgets(6));
    });
  });

  group('BrandedEmptyState', () {
    testWidgets('renders title, subtitle, and CTA', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BrandedEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing here',
            subtitle: 'Try again later.',
            ctaLabel: 'Refresh',
            onCta: () => tapped++,
          ),
        ),
      ));
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Try again later.'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);

      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('omits CTA when not provided', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BrandedEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Empty',
            subtitle: 'Nothing.',
          ),
        ),
      ));
      // No ElevatedButton if there's no CTA wired up.
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
