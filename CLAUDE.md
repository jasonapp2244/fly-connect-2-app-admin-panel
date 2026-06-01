# FlyConnect 2

## Project Overview

FlyConnect is a social networking app for aviation industry employees (pilots, flight attendants, ground crew, gate agents). Users can connect with nearby colleagues, match for travel buddies/dating, share posts, join groups, attend events, and track their travel passports.

## Tech Stack

- **Framework:** Flutter (Dart SDK 3.0.0 - <4.0.0)
- **State Management:** Provider (ChangeNotifier pattern)
- **Navigation:** GoRouter with deep linking
- **Backend:** Firebase (Firestore, Auth, Storage, FCM, Crashlytics, Analytics) — real Firebase is the default
- **Maps:** flutter_map + OpenStreetMap tiles + latlong2
- **Design:** Material3, Inter font, dark navy + neon yellow-green brand colors

## Development Mode

The project runs on **real Firebase** by default:
- Default entry point: `lib/main.dart` (Firebase init + Crashlytics + Analytics + FCM)
- Real providers: `lib/shared/providers/real_providers.dart`
- Firebase config: `lib/core/config/firebase_config.dart`
- Admin web entry: `lib/main_admin.dart`

**Mock mode** is opt-in for fast UI work without a Firebase round-trip:
- Mock entry point: `lib/main_mock.dart`
- Mock providers: `lib/shared/mock/mock_providers.dart`
- Mock data: `lib/shared/mock/mock_data.dart`
- Switches every provider to `isMock: true` (in-memory state, no Firestore queries)

Run real Firebase: `flutter run` (uses `lib/main.dart` automatically).
Run mock mode: `flutter run -t lib/main_mock.dart`.

## Conventions

- **Models** go in `lib/shared/models/models.dart` — plain Dart classes, `const` constructors, `fromMap`/`toMap` factories
- **Providers** are `ChangeNotifier` classes with `updateAuth(AuthProvider)` method
- **Screens** are in `lib/features/<feature>/` — one file per screen
- **Routes** defined as `static const` in `lib/core/constants/app_routes.dart`, registered in `lib/core/utils/app_router.dart`
- **Colors** in `lib/core/constants/app_colors.dart`, **text styles** in `app_text_styles.dart`
- **Bottom sheets** use `showModalBottomSheet` with `RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))`
- **Status colors**: green = success/online, orange = warning, red = error/urgent

## Key Commands

```bash
flutter run                           # Run on real Firebase (default: lib/main.dart)
flutter run -t lib/main_mock.dart     # Run in mock mode (no backend round-trip)
flutter run -t lib/main_admin.dart    # Run the admin web shell
flutter analyze                        # Check for errors
flutter test                          # Run tests
```

## Features

| Feature | Module | Key Files |
|---------|--------|-----------|
| Auth | `features/auth/` | login, signup, otp screens |
| Home/Feed | `features/home/` | feed, create post, stories |
| Matching | `features/match/` | swipe cards, preferences |
| Chat | `features/chat/` | chat list, conversation |
| Events | `features/events/` | browse, create, RSVP |
| Groups | `features/groups/` | list, details, create |
| Profile | `features/profile/` | view, edit, followers |
| Business | `features/business/` | dashboard, analytics, promotions |
| Trips | `features/trips/` | passport/travel tracking |
| Nearby | `features/nearby/` | map/list, SafeCheck |
| SafeCheck | `features/nearby/` | check-in, status badges, history |
| Search | `features/search/` | cross-feature search |
| Notifications | `features/notifications/` | push notification list |
| Settings | `features/settings/` | privacy, account, notifications |
