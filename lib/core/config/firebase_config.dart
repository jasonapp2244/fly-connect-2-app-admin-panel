class FirebaseConfig {
  // ── Web config (from Firebase Console) ─────────────────────
  static const String apiKey = 'AIzaSyATy7l4IIgxxZ0J7iFqQHLO9hCqIeh1CHs';
  static const String authDomain = 'flyconnect-ab4f2.firebaseapp.com';
  static const String databaseURL = 'https://flyconnect-ab4f2-default-rtdb.firebaseio.com';
  static const String projectId = 'flyconnect-ab4f2';
  static const String storageBucket = 'flyconnect-ab4f2.firebasestorage.app';
  static const String messagingSenderId = '361504801284';
  static const String appId = '1:361504801284:web:891ccdee6e7143f3c0ab51';
  static const String measurementId = 'G-DBSSBSMEVR';

  // ── App config ─────────────────────────────────────────────
  // Canonical bundle ID used across google-services.json, AndroidManifest,
  // and iOS Info.plist. Must stay in sync with Firebase Console.
  static const String androidPackageName = 'com.appcurb.flyconnect';
  static const String iosBundleId = 'com.appcurb.flyconnect';

  // ── Deep link scheme ───────────────────────────────────────
  static const String deepLinkScheme = 'flyconnect';
  static const String deepLinkHost = 'app.flyconnect.com';

  // ── Admin role identifier ──────────────────────────────────
  static const String adminRole = 'admin';
}
