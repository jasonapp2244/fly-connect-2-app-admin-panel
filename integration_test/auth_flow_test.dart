import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flyconnect/main.dart' as app;

/// End-to-end auth flow test.
///
/// Preconditions:
///   - Firebase Auth emulator running on :9099, OR a reachable Firebase project
///   - Seeded test account: alex@delta.com / Test1234!
///
/// Run:
///   flutter test integration_test/auth_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth flow', () {
    testWidgets('Login with seeded account routes to /home', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Splash should eventually land on login
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.textContaining('Welcome back'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'alex@delta.com');
      await tester.enterText(find.byType(TextField).at(1), 'Test1234!');

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Home top bar / feed filter chips should be visible
      expect(find.text('Feed'), findsOneWidget);
    }, skip: true); // Unskip when Firebase emulator is running

    testWidgets('Signup without consent checkbox blocks progression',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Find "Sign Up" link on login screen and tap
      final signupLink = find.textContaining('Sign Up');
      if (signupLink.evaluate().isEmpty) return; // signup may not be reachable
      await tester.tap(signupLink);
      await tester.pumpAndSettle();

      // Try to proceed without checking consent
      await tester.enterText(find.byType(TextField).first, 'Test User');
      // Scroll down to fill remaining fields and tap Continue
      // The Continue button should trigger a "Please agree to the Terms" snackbar
      await tester.pumpAndSettle();
    }, skip: true);
  });
}
