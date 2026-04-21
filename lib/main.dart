import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:provider/provider.dart';
import 'core/config/firebase_config.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'shared/providers/real_providers.dart';

Future<void> main() async {
  // Wrap in runZonedGuarded so uncaught async errors also go to Crashlytics.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: FirebaseConfig.apiKey,
        authDomain: FirebaseConfig.authDomain,
        projectId: FirebaseConfig.projectId,
        storageBucket: FirebaseConfig.storageBucket,
        messagingSenderId: FirebaseConfig.messagingSenderId,
        appId: FirebaseConfig.appId,
        measurementId: FirebaseConfig.measurementId,
      ),
    );

    // Crashlytics wiring (Crashlytics is not supported on web).
    if (!kIsWeb) {
      // Disable in debug to avoid polluting the dashboard with dev crashes.
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);

      // Flutter framework errors -> Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Platform async errors (Isolate, etc.) -> Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    // Analytics: log app_open for install/activation funnel
    try {
      await FirebaseAnalytics.instance.logAppOpen();
    } catch (_) {/* analytics is best-effort */}

    // FCM: permission prompt + token storage + foreground listener
    unawaited(NotificationService.instance.init());

    runApp(const FlyConnectApp());
  }, (error, stack) {
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class FlyConnectApp extends StatelessWidget {
  const FlyConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, PostProvider>(
          create: (_) => PostProvider(),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, EventProvider>(
          create: (_) => EventProvider(),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, GroupProvider>(
          create: (_) => GroupProvider(),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, MatchProvider>(
          create: (_) => MatchProvider(),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, TripProvider>(
          create: (_) => TripProvider(),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, SearchProvider>(
          create: (_) => SearchProvider(),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, PromotionProvider>(
          create: (_) => PromotionProvider(),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, SafeCheckProvider>(
          create: (_) => SafeCheckProvider(),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
      ],
      child: MaterialApp.router(
        title: 'FlyConnect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
