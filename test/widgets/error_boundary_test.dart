import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyconnect/shared/widgets/error_boundary.dart';

class _ThrowingWidget extends StatelessWidget {
  const _ThrowingWidget();
  @override
  Widget build(BuildContext context) {
    throw FlutterError('intentional test boom');
  }
}

void main() {
  group('ErrorBoundary', () {
    testWidgets('replaces Flutter red screen with branded fallback',
        (tester) async {
      ErrorBoundary.install();
      // Suppress Flutter's "EXCEPTION CAUGHT BY WIDGETS LIBRARY"
      // dumping to stderr during the test.
      FlutterError.onError = (_) {};

      await tester.pumpWidget(const MaterialApp(
        home: _ThrowingWidget(),
      ));
      await tester.pumpAndSettle();

      // The fallback widget shows this exact heading.
      expect(find.text('Something went wrong'), findsOneWidget);
      // And does NOT show Flutter's default red-screen "EXCEPTION".
      expect(find.textContaining('EXCEPTION CAUGHT'), findsNothing);
    });
  });
}
