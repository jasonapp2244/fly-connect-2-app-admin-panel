# FlyConnect 2

## Project Overview

FlyConnect is a social networking app for aviation industry employees (pilots, flight attendants, ground crew, gate agents). Users can connect with nearby colleagues, match for travel buddies/dating, share posts, join groups, attend events, and track their travel passports.

## Tech Stack

- **Framework:** Flutter (Dart SDK 3.0.0 - <4.0.0)
- **State Management:** Provider (ChangeNotifier pattern)
- **Navigation:** GoRouter with deep linking
- **Backend:** Firebase (Firestore, Auth, Storage, FCM) — currently mock-first
- **Maps:** flutter_map + OpenStreetMap tiles + latlong2
- **Design:** Material3, Inter font, dark navy + neon yellow-green brand colors

## Development Mode

The project runs in **mock mode** by default:
- Entry point: `lib/main_mock.dart`
- Mock providers: `lib/shared/mock/mock_providers.dart`
- Mock data: `lib/shared/mock/mock_data.dart`
- Real Firebase entry: `lib/main.dart` (not wired yet)

To switch to real Firebase: update provider imports from `mock_providers.dart` to `lib/shared/providers/` and configure Firebase credentials in `lib/core/config/firebase_config.dart`.

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
flutter run -t lib/main_mock.dart     # Run in mock mode
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
