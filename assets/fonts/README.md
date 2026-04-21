# Font Assets

**Status: awaiting font files.**

`lib/core/constants/app_text_styles.dart` references `fontFamily: 'Inter'`. Without these files, Flutter falls back to the system default — the app still runs but typography looks slightly off.

## Required files

Download from [rsms.me/inter](https://rsms.me/inter/) or [Google Fonts](https://fonts.google.com/specimen/Inter) and place here:

- `Inter-Regular.ttf` (weight 400)
- `Inter-Medium.ttf` (weight 500)
- `Inter-SemiBold.ttf` (weight 600)
- `Inter-Bold.ttf` (weight 700)
- `Inter-ExtraBold.ttf` (weight 800)

## After adding the files

Uncomment the `fonts:` block in `pubspec.yaml` (it's currently commented out until the files exist) and run `flutter pub get`.
