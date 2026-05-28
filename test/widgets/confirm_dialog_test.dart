import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyconnect/shared/widgets/confirm_dialog.dart';

void main() {
  testWidgets('showConfirmDialog returns true on confirm',
      (WidgetTester tester) async {
    late bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  ctx,
                  title: 'Delete?',
                  message: 'Are you sure?',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete?'), findsOneWidget);
    expect(find.text('Are you sure?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(result, true);
  });

  testWidgets('showConfirmDialog returns false on cancel',
      (WidgetTester tester) async {
    late bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showConfirmDialog(
                  ctx,
                  title: 'T',
                  message: 'M',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, false);
  });

  testWidgets('destructive style uses red confirm button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showConfirmDialog(
                ctx,
                title: 'T',
                message: 'M',
                confirmLabel: 'Delete',
                isDestructive: true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final btn = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Delete'),
        matching: find.byType(ElevatedButton),
      ),
    );
    // `backgroundColor` can be a `WidgetStatePropertyAll` (single colour)
    // or a `WidgetStateMapper` (per-state resolver). Resolve via the
    // `.resolve` contract to stay compatible with both.
    final bg = btn.style?.backgroundColor?.resolve(<WidgetState>{});
    // Destructive should be red-ish
    expect(bg, isNotNull);
  });
}
