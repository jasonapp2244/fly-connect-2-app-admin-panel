# FlyConnect 2 — Architecture

## Directory Structure

```
lib/
  core/
    config/          Firebase configuration
    constants/       AppColors, AppRoutes, AppTextStyles
    services/        Firebase service wrappers
    theme/           Material3 theme
    utils/           GoRouter setup
  features/
    auth/            Login, Signup, OTP screens
    business/        Dashboard, Promotions, Analytics (business role)
    chat/            Chat list, Conversation
    events/          Browse, Create, Details, RSVP
    groups/          List, Details, Create
    home/            Feed, Create Post, Stories, Main Shell
    match/           Swipe cards, Preferences
    nearby/          Nearby users map/list, SafeCheck
    notifications/   Notification list
    onboarding/      Onboarding flow
    profile/         User profile, Edit
    search/          Cross-feature search
    settings/        Privacy, Account, Notifications
    splash/          Splash screen
    trips/           Passport / travel tracking
  shared/
    mock/            Mock data + mock providers (development mode)
    models/          All data models (models.dart)
    providers/       Real Firebase provider stubs
    repositories/    Firebase repository implementations
    widgets/         Shared UI components
  main.dart          Real Firebase entry point
  main_mock.dart     Mock data entry point (default)
```

## Data Flow

```
UI Screen
  -> context.watch<XxxProvider>()  (reads state)
  -> context.read<XxxProvider>().action()  (triggers mutations)
     -> Provider notifies listeners
        -> UI rebuilds
```

All providers are registered in `main_mock.dart` via `ChangeNotifierProxyProvider<AuthProvider, XxxProvider>`.

## Models

All models live in `lib/shared/models/models.dart`:

| Model | Firestore Collection | Purpose |
|-------|---------------------|---------|
| UserModel | users | User profiles, roles |
| PostModel | posts | Social feed posts |
| CommentModel | posts/{id}/comments | Post comments |
| ChatModel | chats | DM and group chats |
| MessageModel | chats/{id}/messages | Chat messages |
| EventModel | events | Events with RSVP |
| GroupModel | groups | User groups |
| MatchModel | matches | Buddy/dating matches |
| NotificationModel | notifications | Push notifications |
| PromotionModel | promotions | Business promotions |
| TripModel | trips | Travel passport entries |
| SafeCheckModel | safeChecks | Safety check-ins |

## SafeCheck Feature

SafeCheck is a location-based safety check-in system allowing users to broadcast their status to nearby FlyConnect users.

### Data Flow

```
User taps FAB on Nearby screen
  -> Bottom sheet opens (status selection modal)
  -> User selects: Safe / Unsure / Need Help + optional message
  -> SafeCheckProvider.checkIn() creates SafeCheckModel
     -> Check-in stored with 24h expiry
     -> notifyListeners() triggers UI update
  -> Nearby screen shows status badges on map markers + list cards
  -> Other users see the status via SafeCheckProvider.latestForUser()
```

### Files

| File | Purpose |
|------|---------|
| `lib/shared/models/models.dart` | SafeCheckModel definition |
| `lib/shared/mock/mock_data.dart` | mockSafeChecks test data |
| `lib/shared/mock/mock_providers.dart` | SafeCheckProvider (mock) |
| `lib/features/nearby/nearby_users_screen.dart` | Main UI: FAB, bottom sheet, map/list badges |
| `lib/features/nearby/safe_check_history_screen.dart` | Check-in history view |
| `lib/features/settings/settings_screen.dart` | Privacy controls |
| `firestore.rules` | safeChecks collection security rules |

### Status Values

| Status | Color | Icon | Meaning |
|--------|-------|------|---------|
| `safe` | Green (#4CAF50) | check_circle | User is safe and settled |
| `unsure` | Orange (#FF9500) | help | Situation is unclear |
| `need_help` | Red (#FF3B30) | warning | User needs assistance |

### Privacy Controls (Settings)

- **Share Location for SafeCheck** — toggle location sharing on/off
- **Approximate Location Only** — city-level only (default on)
- **SafeCheck Visibility** — Everyone / Friends Only / Verified Users
- **SafeCheck Alerts** — notification toggle

## Navigation

Routes defined in `lib/core/constants/app_routes.dart`, registered in `lib/core/utils/app_router.dart`.

### User Shell (bottom nav: 5 tabs)
`/home` | `/events` | `/match` | `/chat` | `/profile`

### Business Shell (bottom nav: 3 tabs)
`/dashboard` | `/promotions` | `/business-events`

### Standalone
`/nearby` | `/safe-check-history` | `/settings` | `/notifications` | `/search` | `/trips` | `/create-post` | `/create-group` | etc.

### Deep Links
`/users/:userId` | `/conversation/:chatId` | `/groups/:groupId` | `/events/:eventId` | `/passport/:userId`

## Firestore Security

Rules in `firestore.rules` use helper functions:
- `isAuth()` — user is authenticated
- `isOwner(uid)` — user owns the resource
- `isAdmin()` — user has admin role
- `isNotBanned()` — user is not banned

Collections: users, posts, chats, events, groups, matches, notifications, safeChecks.
