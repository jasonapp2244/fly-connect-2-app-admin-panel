# Integration Tests

Run with:

```bash
# iOS simulator / Android emulator
flutter test integration_test

# On a specific device
flutter test integration_test -d <device-id>

# Web
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/auth_flow_test.dart -d chrome
```

## Prerequisites

- Firebase Emulator Suite running on `localhost:8080` (Firestore) + `localhost:9099` (Auth).
  Start with `firebase emulators:start --only auth,firestore` if you have `firebase-tools` installed.
- Or: tests run against real Firebase — **caution**, they write to production if not emulated.

## Files

- `auth_flow_test.dart` — login → home → logout loop; signup with consent gate
- `post_create_flow_test.dart` — home → FAB → create post → verify in feed
