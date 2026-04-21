import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Handles FCM lifecycle:
/// - Requests notification permission (iOS + Android 13+)
/// - Stores the device FCM token on the user doc
/// - Refreshes the token on rotation
/// - Listens for foreground messages
///
/// Call [NotificationService.init] from main.dart after Firebase.initializeApp.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<User?>? _authSub;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Web uses a different FCM pipeline (service worker + VAPID key).
    // Mobile-first for now; web push can be wired later with a VAPID key
    // passed to getToken(vapidKey: ...).
    if (kIsWeb) return;

    final messaging = FirebaseMessaging.instance;

    // Ask permission (shows the iOS system dialog; on Android 13+ triggers
    // the POST_NOTIFICATIONS runtime prompt if declared in the manifest).
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // User said no \u2014 skip token registration until they re-enable.
      return;
    }

    // Persist token whenever auth state changes (catches logout/login) and on rotation.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      final token = await messaging.getToken();
      if (token != null) await _saveToken(user.uid, token);
    });

    _tokenSub = messaging.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _saveToken(uid, token);
    });

    // Foreground messages \u2014 deliver to the in-app notification center.
    // Background/terminated messages go through the native handler registered
    // in AndroidManifest (flyconnect_default channel).
    _fgSub = FirebaseMessaging.onMessage.listen((msg) {
      // No-op here \u2014 UI subscribes via NotificationProvider stream.
      // Log in debug to confirm delivery during QA.
      // ignore: avoid_print
      // print('[FCM foreground] ${msg.notification?.title}');
    });
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
    } catch (_) {
      // Doc may not exist yet (first sign-up); the auth listener will retry
      // the next time it fires.
    }
  }

  Future<void> dispose() async {
    await _fgSub?.cancel();
    await _tokenSub?.cancel();
    await _authSub?.cancel();
    _initialized = false;
  }
}
