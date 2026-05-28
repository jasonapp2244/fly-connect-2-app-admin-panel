# iOS Info.plist + Privacy Manifest Audit

Last reviewed: 2026-05-28

## Summary

The iOS app shell at `ios/Runner/Info.plist` is in good shape for App
Store submission once the placeholder values below are replaced. This
document records what each declared key does, what code path uses it,
and what still needs human action.

## Permission usage descriptions

| Key | Status | Notes |
|---|---|---|
| `NSLocationWhenInUseUsageDescription` | Aspirational | SafeCheck + Nearby reference location, but real `geolocator` integration is not yet wired. Description is forward-compatible; no harm in keeping. |
| `NSCameraUsageDescription` | Active | `image_picker` uses the camera for post media + profile photos. |
| `NSPhotoLibraryUsageDescription` | Active | `image_picker` reads from the photo library. |
| `NSUserTrackingUsageDescription` | Active | Firebase Analytics + Crashlytics. iOS 14.5+ ATT prompt is required if any tracking-identifier framework is used; safer to declare. |

## Permissions removed in audit (re-add when features ship)

- `NSPhotoLibraryAddUsageDescription` — was for saving images to the
  library, but no code path actually writes images out today.
- `NSMicrophoneUsageDescription` — declared for video recording, but
  the app does not capture audio anywhere.
- `NSContactsUsageDescription` — declared for "find friends from
  contacts" feature that does not exist yet.

Declaring unused permissions risks two store-side issues:

1. App Privacy nutrition label is inconsistent with actual data flow.
2. Reviewer may ask "where in the app does this prompt appear?" and
   reject if they cannot trigger it during review.

When any of those features lands, re-add the relevant key with a
specific user-facing description.

## URL schemes

- `flyconnect://` — primary deep-link scheme. Wired in
  `app_router.dart` for deep links from emails / push notifications.
- `com.googleusercontent.apps.REPLACE_WITH_REVERSED_CLIENT_ID` —
  Google Sign-In reversed client ID. **MUST be replaced** with the
  real value from `ios/Runner/GoogleService-Info.plist` before iOS
  build. Without this, Google Sign-In returns the user to Safari
  instead of the app.

## Network & encryption

- `NSAppTransportSecurity.NSAllowsArbitraryLoads = false` — strict
  HTTPS only. Matches `usesCleartextTraffic="false"` in
  AndroidManifest. Apple prefers this and it raises trust during
  review.
- `ITSAppUsesNonExemptEncryption = false` — only standard HTTPS/TLS,
  so we're CCATS-exempt. Correct.

## Background modes & FCM

- `UIBackgroundModes` = `["fetch", "remote-notification"]` — required
  for FCM to deliver push notifications when the app is backgrounded.
- `FirebaseAppDelegateProxyEnabled = false` — we manually handle FCM
  in our AppDelegate. Confirm `AppDelegate.swift` registers
  `application:didRegisterForRemoteNotificationsWithDeviceToken:` —
  if not, FCM tokens won't be acquired on iOS.

## Orientation support

- iPhone supports portrait, landscape-left, landscape-right.
- iPad supports all four orientations.

The app is designed portrait-first; landscape layouts are NOT
explicitly tested. Either:

1. **Restrict iPhone to portrait** — safer, simpler. Edit `Info.plist`
   to remove the landscape entries under
   `UISupportedInterfaceOrientations`.
2. **Test every screen in landscape** before submission and fix any
   overflow/clipping issues.

## Still pending (manual action required)

1. **Register the iOS app in Firebase Console** for `flyconnect-ab4f2`
   with bundle id `com.appcurb.flyconnect`. Download
   `GoogleService-Info.plist` and drop it into `ios/Runner/`.
2. **Replace `REPLACE_WITH_REVERSED_CLIENT_ID`** with the
   `REVERSED_CLIENT_ID` value from `GoogleService-Info.plist`.
3. **Add capabilities in Xcode**:
   - Sign in with Apple
   - Push Notifications
   - Background Modes → Remote notifications, Background fetch
4. **Apple Developer Team ID** — set in Xcode → Signing & Capabilities
   before archiving.
5. **APNs Auth Key** — upload to Firebase Console (Cloud Messaging
   settings) so FCM can deliver to iOS.
6. **Decide on iPhone landscape** — either remove it from
   `UISupportedInterfaceOrientations` or QA all screens in landscape.

## PrivacyInfo.xcprivacy quick-check

The file exists at `ios/Runner/PrivacyInfo.xcprivacy`. It declares
Apple-required Data Use categories — re-verify the declared types
match what we actually collect:

| Declared | We actually collect? |
|---|---|
| Email | ✓ (auth) |
| Name | ✓ (profile) |
| Photos/Videos | ✓ (posts, profile photo) |
| Precise location | Aspirational — not wired yet |
| Device ID | ✓ (FCM token, Crashlytics) |
| Crash data | ✓ (Crashlytics) |

`Precise location` should be downgraded to `Coarse location` or
removed entirely until real GPS lands. App Privacy reviewers DO check
this against runtime behaviour.
