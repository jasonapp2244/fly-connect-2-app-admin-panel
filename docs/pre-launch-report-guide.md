# Pre-launch Report — Review Guide

Google's Pre-launch report automatically installs and runs your app on **~20 real devices** (different manufacturers, OS versions, screen sizes) and surfaces crashes, ANRs, accessibility issues, performance regressions, and privacy violations.

You cannot skip this — it runs automatically on every upload. You must **read it and fix anything flagged "Critical"** before promoting a release.

---

## Where to find it

Play Console → your app → **Testing → [track] → (your release) → Pre-launch report details**.

It usually completes within **30–60 minutes** after upload. A banner on the Release dashboard will say "Pre-launch report available."

---

## Sections — what to check

### 1. Stability

| Finding | What it means | What to do |
|---------|---------------|------------|
| Crashes | App crashed on one of Google's test devices | Open the stack trace → fix → re-upload |
| ANRs | App blocked the main thread > 5s | Profile with DevTools; move work off-thread |
| Native crashes | NDK/native code crash (likely Firebase SDK) | Update to latest Firebase versions; reproduce on that device |

**Block ship** if:
- Any crash on launch
- ANRs on any screen that's part of the core flow (login, feed, post-create)

### 2. Performance

| Metric | Acceptable | Block ship if |
|--------|------------|---------------|
| Startup time (cold) | < 2.5s | > 5s on average |
| Frames per second | ≥ 55 during scroll | < 40 on pre-launch devices |
| Memory usage | < 400 MB peak | > 600 MB or OOM kills |

### 3. Accessibility

Google runs **Accessibility Scanner** automatically. Typical findings for a Flutter app:

| Finding | Typical cause | Fix |
|---------|---------------|-----|
| "Image without content description" | IconButton with no `tooltip` | Add `tooltip:` to every IconButton |
| "Small touch target" | < 48dp tap area | Wrap in `InkWell` with padding to 48dp minimum |
| "Low contrast" | Primary color on white fails WCAG AA | Change text color or darken background |
| "Duplicate labels" | Multiple widgets with identical accessibility labels | Add `Semantics` with unique labels |

See `docs/accessibility-audit.md` for a pre-submission TalkBack checklist.

### 4. Security & trust

Google's static analyzer checks for:

| Finding | What it means |
|---------|---------------|
| `usesCleartextTraffic=true` | HTTP traffic allowed (we removed this) |
| Hardcoded secrets | API keys in plaintext in code |
| Unsafe deep links | Intent filters exposed to any app |
| SSL/TLS misconfig | Accepting invalid certificates |

Our AndroidManifest is already hardened against most of these.

### 5. Privacy — "Data safety mismatch"

This is the **#1 reason apps get rejected** after Data Safety form rollout. Google's scanner detects what data your app actually sends and compares to what you declared.

If it flags you, re-read `docs/data-safety-form.md` line-by-line against what you actually ship.

Common mismatches:
- Firebase Analytics logs user_id but data-safety form didn't declare User IDs
- FCM token persistence counts as Device ID (we declared this ✅)
- Crashlytics sends device model — counts as diagnostics (we declared this ✅)

### 6. Deprecated APIs

Target SDK 34 (Android 14) requires using new APIs for:
- Foreground services (you must declare `foregroundServiceType`)
- Scoped storage (no `MANAGE_EXTERNAL_STORAGE` unless justified)
- Notification permission (you must request `POST_NOTIFICATIONS`) — we handle this ✅

---

## Screenshots from the report

The pre-launch report includes automated screenshots from each device. Review them for:
- Layout breakage on small/large screens
- Dark mode glitches (if your theme supports it)
- RTL (Arabic, Hebrew) layout breaks
- Missing strings (default English used on non-English locales)

---

## Common FlyConnect-specific failures to watch for

| Symptom | Likely cause |
|---------|--------------|
| Crash on launch, Device: Pixel 8 Android 14 | Missing `POST_NOTIFICATIONS` runtime request (we have this) |
| Crash on login, Device: any | Missing SHA-1 fingerprint in Firebase Console |
| ANR on home feed | PostProvider stream not cancelled in dispose |
| Pre-launch skipped Firebase Auth | Test account credentials wrong in App access |
| "Metadata mismatch" flag | Google Sign-In REVERSED_CLIENT_ID placeholder never replaced in Info.plist |

---

## Triage workflow

1. Open the pre-launch report
2. Sort issues by **Severity** (Critical → High → Medium → Low)
3. For each Critical issue:
   - Read the stack trace
   - Can you reproduce on your dev device? If yes → fix
   - If no → check which device/OS version it's on → boot an emulator of that combo → reproduce → fix
4. Re-build AAB, bump the build number, re-upload
5. Wait for new pre-launch report
6. Once no Critical issues remain → promote to next testing track

---

## When to override

Google doesn't let you "override" — but you can **promote to production with pre-launch warnings** if:
- The warning is a known limitation (e.g., TalkBack on a specific device version)
- You've documented the limitation in release notes
- You have a plan to fix in the next release

Never promote with an active Critical crash. If you do, Google will often auto-halt your rollout within 24 hours.

---

## Red flags you should never ignore

- 🚨 **Crash rate > 2%** on any device
- 🚨 **Screenshots showing user PII** (real email, photo) — this means a real account was used during testing; make sure your test account has dummy data
- 🚨 **"Deceptive behavior" flag** — usually a button click leads nowhere
- 🚨 **Privacy API misuse warning** (e.g., reading IMEI) — some transitive dep is misbehaving

---

## Reference

- Official docs: https://support.google.com/googleplay/android-developer/answer/7002270
- Accessibility Scanner: https://support.google.com/accessibility/android/answer/6376570
- Target SDK requirements: https://support.google.com/googleplay/android-developer/answer/11926878
