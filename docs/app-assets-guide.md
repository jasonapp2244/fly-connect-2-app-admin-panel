# App Assets Guide — Icon, Feature Graphic, Screenshots

Play Console requires specific visual assets before you can publish. This guide tells you exactly what to produce, at what size, and how to generate them.

---

## 1. App icon

### Requirements

| Asset | Size | Format | Where used |
|-------|------|--------|------------|
| Play Store high-res icon | 512×512 px | PNG (32-bit, no alpha channel) | Store listing, search results, featured placements |
| Launcher adaptive foreground | 432×432 px (inside 108×108 safe zone) | PNG 32-bit | Device home screens, app drawer |
| Launcher adaptive background | 432×432 px | PNG or solid color | Behind adaptive foreground |
| Legacy launcher icon | 48×48, 72×72, 96×96, 144×144, 192×192 px | PNG | Pre-Android-8 devices |

### Design guidelines

- **Brand colors:** primary `#D4F53C` (neon yellow-green), dark `#1A1D27`
- Adaptive icons are **masked to a circle, squircle, or rounded square** depending on device. Keep the important visual inside the **inner 66% circle** (safe zone).
- Do not use photos — use flat vector or minimal illustration.
- Iconography for FlyConnect: an airplane silhouette, a ✈️ glyph on the `#D4F53C` background, or a connected-nodes graphic on dark navy.

### Generate from a single master

Use `flutter_launcher_icons`:

**Step 1 — Create master asset**

Export a single 1024×1024 PNG of your finalized icon design from Figma/Illustrator/etc. Save as `assets/icon/icon.png` and `assets/icon/icon-foreground.png` (the foreground may be slightly different with extra padding).

**Step 2 — Add to pubspec.yaml**

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.1

flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "assets/icon/icon.png"
  min_sdk_android: 23
  adaptive_icon_background: "#1A1D27"
  adaptive_icon_foreground: "assets/icon/icon-foreground.png"
  remove_alpha_ios: true
  web:
    generate: true
    image_path: "assets/icon/icon.png"
```

**Step 3 — Generate**

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

This populates:
- `android/app/src/main/res/mipmap-*/ic_launcher.png`
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (adaptive)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`
- `web/icons/*`

**Step 4 — Commit**

```bash
git add android/app/src/main/res ios/Runner/Assets.xcassets web/icons assets/icon
git commit -m "Add app icon assets"
```

---

## 2. Feature graphic

Required by Play Console for every app.

| Property | Value |
|----------|-------|
| Size | **1024×500 px** |
| Format | JPG or 24-bit PNG (no alpha) |
| Max size | 1 MB |

### Design guidelines

- This is the hero image on your Play Store listing. It shows on top.
- Should clearly communicate **what the app is**: "Social network for airline crew"
- **Do not include text that duplicates the app title** (redundant and penalized)
- Safe area: keep essential elements in the **center 70%** — the edges may be cropped on different placements
- Avoid screenshots of the UI — feature graphic is separate from the screenshots section

### Layout suggestion

```
┌──────────────────────────────────────────────┐
│                                              │
│    [Stylized airplane + crew silhouette]     │
│                                              │
│         Connect with Your Flight Crew        │
│                                              │
└──────────────────────────────────────────────┘
```

Background: gradient `#1A1D27` → `#D4F53C`. Tagline in `Inter ExtraBold` at ~72pt.

---

## 3. Screenshots

### Phone screenshots (required)

| Property | Value |
|----------|-------|
| Min count | 2 |
| Max count | 8 |
| Min resolution | 320×320 px on short side |
| Max resolution | 3840 px on short side |
| Aspect ratio | 16:9 or 9:16 |
| Recommended size | **1080×1920 px** (portrait, 9:19.5) |
| Format | JPG or 24-bit PNG |

### Tablet screenshots (recommended — boosts Play rank)

- **7-inch tablet:** 1024×600 or 1200×1920 px (min 2)
- **10-inch tablet:** 1920×1200 px (min 2)

### Shot list — 8 screenshots to produce

| # | Screen | Caption overlay | Key state to capture |
|---|--------|-----------------|---------------------|
| 1 | Home feed | "Your airline crew, in your pocket" | 2 posts visible, crew deals strip, filter chips |
| 2 | Match screen | "Meet your next layover buddy" | Swipe card mid-drag with "LIKE" overlay |
| 3 | Chat list | "Chat with crew from every airline" | 2 DMs + 1 group chat with unread badges |
| 4 | Event detail | "Find crew events worldwide" | Upcoming event with RSVP button + location |
| 5 | Create post | "Share your layover moments" | Photo selected + caption typed |
| 6 | Crew Deals (`/offers`) | "Exclusive savings for crew" | 3 active promos with discount badges |
| 7 | Digital passport | "Track every country you've flown to" | Stamps grid with flag emojis |
| 8 | Profile | "Your crew card, on every device" | Filled profile with airline, position, stats |

### Production tips

- Use **seeded test accounts only** — never real user data in screenshots. Apple and Google both reject listings with real PII visible.
- Capture at **device-native resolution** (Pixel 8 = 1080×2400) then downscale if needed.
- Add a **device frame** for polish: https://deviceframes.com/ or `adb shell screencap -p /sdcard/s.png` raw then frame in Figma.
- **Caption overlays** help conversion by ~30% — add them in Figma/Sketch.
- Keep **captions under 5 words** — they show small.
- Ensure **status bar is hidden or clean** (no notifications, full battery, full signal).

### How to capture

```bash
# On device with adb connected
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png
```

Or in-app: Android's default screenshot (Vol Down + Power).

For **consistent lighting and no notifications**, enable Do Not Disturb mode on the test device.

---

## 4. Promo video (optional but recommended)

| Property | Value |
|----------|-------|
| Hosting | YouTube (not uploaded directly to Play) |
| Length | **30 seconds or less** |
| Orientation | Same as phone screenshots (portrait or landscape) |
| Must show | Real app use, not just a trailer |

YouTube URL goes in Play Console → Main store listing → Video.

### Quick-to-shoot structure (30s)

- 0–3s: Logo + tagline ("FlyConnect — Social network for airline crew")
- 3–10s: Fast scroll through feed with captions flashing
- 10–18s: Swipe-match animation → match banner
- 18–24s: Chat + group with "layover plans" message
- 24–28s: SafeCheck flash + crew deals
- 28–30s: Logo + "Free on Google Play"

Record with **Android Studio's built-in screen recorder** (Logcat → Screen Record) or `adb shell screenrecord`.

---

## 5. Short promotional graphic (for Play Pass / Editor's picks)

Not required but available:

| Property | Value |
|----------|-------|
| Size | 180×120 px |
| Format | JPG or 24-bit PNG |

Only visible if Google's editorial team features the app.

---

## 6. TV banner (NOT NEEDED)

Skip unless you're shipping to Android TV — FlyConnect is a phone-first social app.

---

## 7. Wear OS assets (NOT NEEDED)

Skip.

---

## 8. Checklist before uploading

- [ ] Icon: 512×512 PNG with no alpha channel
- [ ] Adaptive icon foreground + background PNGs in mipmap-anydpi-v26
- [ ] Feature graphic: 1024×500 JPG or PNG (no alpha, under 1 MB)
- [ ] Minimum 2 phone screenshots (recommended 4–6)
- [ ] Tablet screenshots if you're targeting tablets
- [ ] No real user PII in any asset
- [ ] No competitor brand names or logos in any asset
- [ ] No "best app ever" / "#1 social app" superlatives (Google penalizes)
- [ ] Screenshots captioned with concise, feature-focused copy

---

## 9. Asset file naming

Suggested structure for your design handoff:

```
design/play-store/
├── icon/
│   ├── icon-512.png
│   ├── icon-foreground-432.png
│   └── icon-background-432.png
├── feature-graphic/
│   └── feature-1024x500.png
├── screenshots/
│   ├── phone/
│   │   ├── 01-home-feed.png
│   │   ├── 02-match.png
│   │   ├── 03-chat.png
│   │   ├── 04-event.png
│   │   ├── 05-create-post.png
│   │   ├── 06-crew-deals.png
│   │   ├── 07-passport.png
│   │   └── 08-profile.png
│   └── tablet/
│       ├── 7in-home.png
│       └── 10in-home.png
└── promo-video/
    └── promo-30s.mp4
```

Upload each file to Play Console → Main store listing → relevant section.

---

## 10. iOS equivalents (for the same shoot)

While you're producing these, capture the same shot list for App Store Connect:

| Device | Size |
|--------|------|
| iPhone 6.7" (15 Pro Max) | 1290×2796 |
| iPhone 6.5" (14 Plus) | 1284×2778 |
| iPad Pro 12.9" (6th gen) | 2048×2732 |
| App icon | 1024×1024 PNG, no alpha |

This saves you doing the photoshoot twice.
