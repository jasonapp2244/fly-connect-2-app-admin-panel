# Release Build Guide — Android AAB

## Prerequisites

- [ ] `android/key.properties` exists (see `docs/keystore-setup.md`)
- [ ] Keystore file exists at the path in `key.properties`
- [ ] `flutter doctor` reports no issues
- [ ] `google-services.json` is in `android/app/`
- [ ] SHA-1 and SHA-256 fingerprints are registered in Firebase Console

---

## Step 1 — Clean

```bash
flutter clean
flutter pub get
```

---

## Step 2 — Bump version in `pubspec.yaml`

```yaml
# Format: marketing+build
# First release:
version: 1.0.0+1

# Subsequent:
version: 1.0.1+2
version: 1.1.0+3
version: 2.0.0+10   # build number monotonically increases
```

**Key rule:** Play Console **will reject** an AAB with a build number (`+N`) that's not higher than the last uploaded build. The marketing version (e.g., `1.0.0`) can stay the same across builds in a track.

---

## Step 3 — Build the AAB

```bash
flutter build appbundle --release
```

On success, you'll see:

```
Running Gradle task 'bundleRelease'...
✓ Built build/app/outputs/bundle/release/app-release.aab (XX.X MB).
```

If the file is under 10 MB, something is wrong (probably an asset or native dep missing). Expected size for FlyConnect at launch: ~30–50 MB.

---

## Step 4 — Verify the AAB

### Signing

```bash
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/release/app-release.aab
```

Look for: `jar verified.` — not `warning: This jar contains signatures that don't include a timestamp.`

### Bundle contents

```bash
# Install bundletool if you haven't:
# https://github.com/google/bundletool/releases
bundletool build-apks \
  --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=build/app/outputs/bundle/release/app-release.apks \
  --ks=/path/to/flyconnect-release.jks \
  --ks-pass=pass:YOUR_KEYSTORE_PASSWORD \
  --ks-key-alias=flyconnect

bundletool install-apks \
  --apks=build/app/outputs/bundle/release/app-release.apks
```

This installs the app on your connected device using the same split-APK flow Play Store would serve.

### Smaller alternative (APK for local smoke test only)

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The APK is **not** what you upload to Play — it's just for local testing.

---

## Step 5 — Smoke test on a real device

Follow `docs/manual-smoke-test.md` end-to-end on the installed release build. **Do not upload until the smoke test passes.**

Minimum must-pass checks:

- [ ] App launches without crashing
- [ ] Login works (email/password)
- [ ] Google Sign-In works (if SHA-1 is registered)
- [ ] A post can be created with an image
- [ ] Push permission prompt appears (Android 13+)
- [ ] A test push notification from Firebase Console reaches the device
- [ ] Delete Account flow completes
- [ ] All destructive actions ask for confirmation

---

## Step 6 — Upload to Play Console

1. Play Console → your app → **Testing → Internal testing** → **Create new release**
2. Upload `app-release.aab`
3. Add release notes (copy from `docs/store-listing.md` → "What's New")
4. Review Play Console's automatic pre-launch report (see `docs/pre-launch-report-guide.md`)
5. Save → Review → **Start rollout to Internal testing**

Start with **Internal testing** (up to 100 testers, instant rollout). Only promote to Closed testing → Open testing → Production after you've validated end-to-end on real devices.

---

## Step 7 — Monitoring after rollout

- **Crashlytics:** Firebase Console → Crashlytics — watch for new issues for 24 hours
- **Play Console → Statistics:** install rate, crash rate, ANR rate
- **Play Console → Pre-launch report:** automated Google test results on ~20 real devices

If Crashlytics shows a spike above 1% session crash rate, pause rollout and investigate.

---

## Common build failures

### `Execution failed for task ':app:signReleaseBundle'`

`key.properties` missing, wrong paths, or wrong password.

### `AAPT: error: resource mipmap/ic_launcher not found`

Icons were never generated. Run `flutter pub run flutter_launcher_icons` after configuring in `pubspec.yaml`.

### `Duplicate class found in modules`

Two deps bring in conflicting versions. `flutter pub deps | grep <classname>` to find the culprit; add an override in `pubspec.yaml → dependency_overrides`.

### `Unable to find bundled Java version`

Android Studio or standalone JDK mismatch. Ensure Java 17 is active:

```bash
java -version   # should print 17.x.x
```

### AAB > 150 MB

Play Console limit. Typical causes:
- Unoptimized images (run through tinypng.com)
- Debug symbols not stripped (`minify: true` + `shrinkResources: true` — already set in our config)
- Multiple architectures bundled when unnecessary

Build per-architecture with:

```bash
flutter build appbundle --release --target-platform android-arm64
```
