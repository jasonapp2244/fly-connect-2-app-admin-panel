# Accessibility Audit — TalkBack Checklist

**Why this matters for Play Store:** Google's Pre-launch Report runs **Accessibility Scanner** on every upload. Flagged issues surface in your Console dashboard, and a pattern of violations can stall promotion from testing to production tracks. Beyond store policy, ~15% of mobile users rely on TalkBack or screen readers for at least some tasks — making the app accessible is a real user-count decision.

---

## 0. Turn on TalkBack

Android device → **Settings → Accessibility → TalkBack → On.**

The first-time tutorial walks you through gestures. Key ones for this audit:

| Gesture | Action |
|---------|--------|
| Single tap | Focus an element and announce it |
| Double tap | Activate the focused element |
| Swipe right / left | Move focus to next / previous element |
| Swipe down then right | Open reading controls |
| Two-finger swipe | Scroll |

---

## 1. Launch & first-run

| Check | Target | How |
|-------|--------|-----|
| Splash screen doesn't trap focus | Focus moves automatically after 3s | Observe TalkBack behavior on launch |
| Login screen announces "Welcome back" | ✅ | Swipe around headings |
| Email / Password fields announce their labels | ✅ | Focus each field |
| "Forgot password?" is reachable by swipe | ✅ | Swipe through the form |
| "G" button for Google Sign-In announces "Google sign in" | ❌ TODO — needs `Semantics(label: 'Sign in with Google')` | Add semantic label |
| Apple icon announces "Apple sign in" | ❌ TODO — same | Add semantic label |

## 2. Navigation

| Check | Expected announcement |
|-------|----------------------|
| Drawer menu button | "Menu, button" |
| Bottom nav "Home" | "Home, tab, 1 of 5, selected" |
| Bottom nav "Match" | "Match, tab, 3 of 5, not selected" |
| Back button in appbars | "Navigate up, button" |

## 3. Home feed

| Check | Expected |
|-------|----------|
| Filter chips | "Feed, selected, filter chip" etc. |
| Stories row — "Your Story" card | "Your story, add a story, button" |
| Post card — author name | "Alex Johnson, posted 3 hours ago" |
| Post card — image | Ideally has alt text from caption (fallback: "Post image") |
| Like button | "Not liked, double tap to like. Like count: 5" |
| Share button | "Share post, button" |
| Bookmark button | "Not saved, double tap to save" |
| "more_horiz" options | "More options, button" |

**Common failures to fix:**
- `IconButton` without `tooltip:` → TalkBack announces "Unlabelled button"
- Stacked Texts with the same semantic label → user hears "Alex Alex Alex"
- Image widgets without `Semantics(label: …)`

## 4. Create post

| Check | Expected |
|-------|----------|
| Caption field announces "What's on your mind, edit box" | ✅ (Flutter TextField handles) |
| Camera button announces "Camera, button" | ✅ |
| Gallery button announces "Gallery, button" | ✅ |
| Audience dropdown announces current selection | ✅ |
| Share button disabled when empty → announced as "dimmed" | ❌ TODO — add `enabled:` and `Semantics(enabled: …)` |

## 5. Chat

| Check | Expected |
|-------|----------|
| Conversation bubbles are in reading order (oldest → newest) | ✅ (ListView natural order) |
| Each message announces sender name + time | ✅ |
| Image attachments announce "Image message" | ❌ TODO when image messages ship |
| Input field announces label | ✅ |
| Send button announces "Send message, button" | ⚠️ Verify |

## 6. Admin Dashboard

Admin is desktop-first; mobile TalkBack audit is lower priority. **If you're shipping admin-as-mobile:**
- Sidebar items must each announce their label and "selected" state
- Stat cards must read like "Total Users: 143, card"
- Tables: each row must be reachable by swipe

## 7. Dialogs and sheets

| Check | Expected |
|-------|----------|
| Confirm dialog focus lands on title | ✅ (Flutter default) |
| Destructive action button is announced with emphasis | ✅ ("Delete, button") |
| Dismissable sheets announce "Dismiss, button" or have a close affordance | ⚠️ Verify modal bottom sheets |

## 8. Forms

| Check | Expected |
|-------|----------|
| Required fields are marked as such | ❌ TODO — add `Semantics(label: 'Email, required')` where applicable |
| Errors are announced when they appear | ❌ TODO — wrap inline errors in `Semantics(liveRegion: true)` |
| Submit button indicates loading state | ✅ (we have `isLoading` param on PrimaryButton) |

---

## Touch target sizing

Apple HIG + WCAG 2.5.5 require a **minimum 44×44 pt** touch target. Android Material guideline is **48×48 dp**.

Run the **Accessibility Scanner** app (free, Play Store) on each screen:

1. Settings → Accessibility → Accessibility Scanner → On
2. Open your app → tap the floating Accessibility Scanner button → "Capture"
3. Review flagged small targets

**Known small targets in FlyConnect (from prior QA):**
- Join/Leave buttons on groups list (24dp tall) → wrap in `SizedBox(height: 48, …)` or increase padding
- View/Ban/Verify buttons on admin users table → same

## Color contrast

WCAG AA requires **4.5:1** for normal text, **3:1** for large text.

Key colors:

| Combo | Ratio | Passes AA? |
|-------|------:|:----------:|
| `#1A1D27` text on white | 13.6 | ✅ |
| `#8A8D9A` text on white | 4.4 | ❌ (borderline) |
| `#D4F53C` text on white | 1.7 | ❌ **fails** |
| `#D4F53C` text on `#1A1D27` dark | 8.0 | ✅ |
| White text on `#D4F53C` | 1.7 | ❌ **fails** |

**Offenders to fix before submission:**
- Chat screen "Online" indicator: `AppColors.primary` on white → change to `AppColors.online` green
- Story viewer "View" button: `AppColors.primary` on white → use `AppColors.dark`

## Dynamic text size

Ensure the app doesn't break at 200% text size:

Device → **Settings → Display → Font size → Largest.**
Re-test all the core screens:
- Login: fields must not overflow
- Feed: post cards must not clip
- Chat: messages must wrap, not overflow

Flutter generally handles this well if you don't set explicit `height:` on text widgets.

---

## Semantics additions to make before submission

These are small code changes. List compiled from above:

| File | Change |
|------|--------|
| `lib/features/auth/login_screen.dart` | Wrap Google `SocialLoginButton` in `Semantics(label: 'Sign in with Google')` ✅ done |
| `lib/features/auth/login_screen.dart` | Wrap Apple `SocialLoginButton` in `Semantics(label: 'Sign in with Apple')` ✅ done |
| `lib/features/home/home_screen.dart` | Add `tooltip:` to every `IconButton` that lacks one (share, bookmark, more_horiz) ✅ done |
| `lib/features/chat/conversation_screen.dart` | Add `tooltip:` to back, more_vert, attach buttons ✅ done |
| `lib/features/groups/group_details_screen.dart` | `tooltip:` on back, more_vert, chat, remove-member ✅ done |
| `lib/features/nearby/nearby_users_screen.dart` | `tooltip:` on back, view-toggle, dismiss ✅ done |
| `lib/features/nearby/safe_check_history_screen.dart` | `tooltip:` on back ✅ done |
| `lib/features/profile/profile_screen.dart` | `tooltip:` on back, notifications, more_horiz ✅ done |
| `lib/features/profile/edit_profile_screen.dart` | `tooltip:` on close ✅ done |
| `lib/features/profile/edit_profile_details_screen.dart` | `tooltip:` on close ✅ done |
| `lib/features/chat/chat_screen.dart` | "New message" already has tooltip ✅ |
| Global | Change `AppColors.primary` text on white surfaces to `AppColors.dark` (contrast fix) — pending |

### Audit pass — 2026-05-28

Swept all top-priority screens (login, home, nearby, profile, chat conversation,
group details, edit profile, SafeCheck history) and added tooltips to every
unlabelled `IconButton`. Login social buttons wrapped in `Semantics(button: true,
label: ...)` so TalkBack announces "Sign in with Google / Apple, button" instead
of just "G, button" / "apple icon, button".

Outstanding (tracked separately):
- Contrast fix for `AppColors.primary` on white (e.g. chat "Online" indicator,
  story viewer "View" button) — needs a token-level change, not screen-by-screen.
- Required-field semantics on auth/signup forms (`Semantics(label: 'Email, required')`).
- Inline form errors wrapped in `Semantics(liveRegion: true)` so they're announced
  the moment they appear.
- Touch target audit with Accessibility Scanner on physical device — needs the
  APK build that's blocked on the Android keystore.

---

## Tools

- **Android Accessibility Scanner** (Google, free): https://play.google.com/store/apps/details?id=com.google.android.apps.accessibility.auditor
- **Flutter Semantics Debugger:** wrap your app in `SemanticsDebugger()` during development to see what TalkBack would read
- **Chrome Lighthouse** (for `/privacy` and `/terms` pages if hosted as web)

---

## Exit criteria

Before promoting to Open testing / Production:

- [ ] All interactive elements have accessible names (TalkBack swipe-through audit passes)
- [ ] No unlabelled buttons
- [ ] No touch targets under 44×44 dp
- [ ] No contrast failures on text the user must read (buttons, body copy, labels)
- [ ] Accessibility Scanner shows zero Critical or High findings
- [ ] Pre-launch report Accessibility section clean
