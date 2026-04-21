import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyconnect/features/common/not_found_screen.dart';

void main() {
  testWidgets('NotFoundScreen renders default title and message',
      (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const NotFoundScreen()),
        GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Home'))),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('Not found'), findsOneWidget);
    expect(find.textContaining('no longer available'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
  });

  testWidgets('NotFoundScreen accepts custom title and message',
      (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const NotFoundScreen(
            title: 'Promotion not found',
            message: 'This offer has expired.',
          ),
        ),
        GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Home'))),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('Promotion not found'), findsOneWidget);
    expect(find.text('This offer has expired.'), findsOneWidget);
  });

  testWidgets('Back to Home navigates to /home',
      (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const NotFoundScreen()),
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('HOME_ROUTE')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();

    expect(find.text('HOME_ROUTE'), findsOneWidget);
  });
}
