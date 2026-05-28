import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyconnect/shared/widgets/async_boundary.dart';

void main() {
  group('AsyncBoundary.future', () {
    testWidgets('shows loading then renders builder with resolved data',
        (tester) async {
      final completer = Completer<String>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AsyncBoundary<String>.future(
            future: () => completer.future,
            builder: (data) => Text(data),
            // Skeleton-style loading is fine; supply a stub for stability.
            loadingBuilder: (_) => const Text('LOADING'),
          ),
        ),
      ));
      expect(find.text('LOADING'), findsOneWidget);
      completer.complete('Hello');
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('LOADING'), findsNothing);
    });

    testWidgets('shows error UI with Retry on failure', (tester) async {
      var calls = 0;
      Future<String> doFetch() {
        calls++;
        if (calls == 1) return Future.error('boom');
        return Future.value('Recovered');
      }

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AsyncBoundary<String>.future(
            future: doFetch,
            builder: (data) => Text('DATA:$data'),
            loadingBuilder: (_) => const Text('LOADING'),
            // Crashlytics call would throw outside a Firebase context.
            reportToCrashlytics: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('DATA:Recovered'), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('isEmpty + emptyBuilder fires when data is empty',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AsyncBoundary<List<int>>.future(
            future: () => Future.value(<int>[]),
            builder: (data) => Text('count=${data.length}'),
            isEmpty: (data) => data.isEmpty,
            emptyBuilder: (_) => const Text('NO_DATA'),
            reportToCrashlytics: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('NO_DATA'), findsOneWidget);
      expect(find.text('count=0'), findsNothing);
    });
  });

  group('AsyncBoundary.stream', () {
    testWidgets('rebuilds on each new stream value', (tester) async {
      final controller = StreamController<int>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AsyncBoundary<int>.stream(
            stream: controller.stream,
            builder: (n) => Text('value=$n'),
            loadingBuilder: (_) => const Text('LOADING'),
            reportToCrashlytics: false,
          ),
        ),
      ));
      expect(find.text('LOADING'), findsOneWidget);

      controller.add(1);
      // Stream events are delivered on the microtask queue; pump once
      // to drain the microtask, again to rebuild.
      await tester.pump(Duration.zero);
      await tester.pump();
      expect(find.text('value=1'), findsOneWidget);

      controller.add(42);
      await tester.pump(Duration.zero);
      await tester.pump();
      expect(find.text('value=42'), findsOneWidget);

      await controller.close();
    });
  });
}
