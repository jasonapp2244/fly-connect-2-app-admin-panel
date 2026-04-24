import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'shared/mock/mock_providers.dart';

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
