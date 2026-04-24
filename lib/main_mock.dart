import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'shared/providers/auth_provider.dart' show AuthProvider;
import 'shared/providers/user_provider.dart' show UserProvider;
import 'shared/providers/post_provider.dart' show PostProvider;
import 'shared/providers/chat_provider.dart' show ChatProvider;
import 'shared/providers/event_provider.dart' show EventProvider;
import 'shared/providers/group_provider.dart' show GroupProvider;
import 'shared/providers/match_provider.dart' show MatchProvider;
import 'shared/providers/notification_provider.dart' show NotificationProvider;
import 'shared/providers/trip_provider.dart' show TripProvider;
import 'shared/providers/search_provider.dart' show SearchProvider;
import 'shared/providers/promotion_provider.dart' show PromotionProvider;
import 'shared/providers/safe_check_provider.dart' show SafeCheckProvider;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyAViMZd_Vv4rrFjO5r_Jbd3wogHAOlOUzo',
      projectId: 'flyconnect-ab4f2',
      messagingSenderId: '361504801284',
      appId: '1:361504801284:android:0ebf704e8b9876fbc0ab51',
      storageBucket: 'flyconnect-ab4f2.firebasestorage.app',
    ),
  );
  runApp(const FlyConnectApp());
}

class FlyConnectApp extends StatelessWidget {
  const FlyConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // All providers use isMock: true — no Firestore queries, all data is in-memory
        ChangeNotifierProvider(create: (_) => AuthProvider(isMock: true)),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(isMock: true),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, PostProvider>(
          create: (_) => PostProvider(isMock: true),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(isMock: true),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, EventProvider>(
          create: (_) => EventProvider(isMock: true),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, GroupProvider>(
          create: (_) => GroupProvider(isMock: true),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, MatchProvider>(
          create: (_) => MatchProvider(isMock: true),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(isMock: true),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, TripProvider>(
          create: (_) => TripProvider(isMock: true),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, SearchProvider>(
          create: (_) => SearchProvider(isMock: true),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, PromotionProvider>(
          create: (_) => PromotionProvider(isMock: true),
          update: (_, auth, p) { p!.updateAuth(auth); return p; }),
        ChangeNotifierProxyProvider<AuthProvider, SafeCheckProvider>(
          create: (_) => SafeCheckProvider(isMock: true),
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
