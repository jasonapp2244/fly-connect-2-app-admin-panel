# Admin Web Target — Build & Deploy

A separate Flutter web build for moderation staff. Admins do NOT need
the mobile app — they go to `admin.flyconnect.app` (or whatever
hostname is configured) and sign in.

## What it includes / excludes

**Included:**
- Admin sign-in screen (`/login`) with email + password only
- Role gate: non-admin accounts are signed out with an error
- 12 admin pages (Dashboard, Users, Reports, Content, SafeCheck, Events,
  Promotions, Businesses, GDPR, Audit Log, Analytics, Notifications)
- Audit logging on every mutation (`audit_log` Firestore collection)

**Excluded** (vs. the full app):
- Splash, onboarding
- Consumer shell (home/feed, match, chat, trips, settings)
- Business shell (business dashboard, promotion CRUD, etc.)
- Match/Trip/Search/Chat providers (smaller bundle, faster load)

## Files

| File | Role |
|---|---|
| `lib/main_admin.dart` | Entry point — initialises Firebase + admin providers + `MaterialApp.router` |
| `lib/core/utils/admin_router.dart` | GoRouter with redirect guard (must be `role == 'admin'`) |
| `lib/features/admin/admin_login_screen.dart` | Email/password form with role check |
| `lib/features/admin/admin_shell.dart` | Reused — sidebar navigation |
| `lib/features/admin/admin_*_page.dart` | Reused — 12 admin pages |

## Local development

```bash
flutter run -d chrome -t lib/main_admin.dart --web-port 8090
```

Open `http://localhost:8090` and sign in with an admin account
(`alan123@gmail.com` / `Admin@1234`).

## Production build

```bash
flutter build web -t lib/main_admin.dart -o build/admin_web --release
```

Output goes to `build/admin_web/`. The full FlyConnect web build stays
in `build/web/` and is not touched.

## Firebase Hosting (separate target)

`firebase.json` defines a hosting target named `admin` pointing at
`build/admin_web`. To deploy:

```bash
# One-time: associate the hosting target with a Firebase Hosting site
firebase target:apply hosting admin <your-hosting-site-id>

# Every deploy
flutter build web -t lib/main_admin.dart -o build/admin_web --release
firebase deploy --only hosting:admin
```

Where `<your-hosting-site-id>` is e.g. `flyconnect-admin` (you create
this in the Firebase Console under Hosting → Add another site).

## CORS / Firestore rules

The admin build talks to the same Firestore project as the mobile app.
No CORS changes needed (Firebase JS SDK handles auth via the same
backing project).

Make sure `firestore.rules` grants admin actions to documents — most
collections already check `request.auth.uid` against an admin allowlist
or check the user's `role` field.

## Bundle size

Stripping consumer/business providers reduces tree-shaken JS by roughly
15–25%. Run `flutter build web --analyze-size --target-platform web` to
see exact figures.
