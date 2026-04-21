import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)));
    _controller.forward();

    Future.delayed(const Duration(seconds: 2), _routeNext);
  }

  Future<void> _routeNext() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('onboarding_seen') ?? false;
      if (!mounted) return;
      context.go(seen ? AppRoutes.login : AppRoutes.onboarding);
      return;
    }
    // Already authenticated \u2014 fetch role, route to correct shell
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = doc.data()?['role'] as String? ?? 'user';
      if (!mounted) return;
      switch (role) {
        case 'admin':
          context.go('/admin/dashboard');
          break;
        case 'business':
          context.go('/dashboard');
          break;
        default:
          context.go(AppRoutes.home);
      }
    } catch (_) {
      if (mounted) context.go(AppRoutes.home);
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 100, height: 100,
                  decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(24)),
                  child: const Center(child: Text('✈️', style: TextStyle(fontSize: 48)))),
                const SizedBox(height: 20),
                const Text('FlyConnect', style: TextStyle(color: Colors.white,
                  fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                if (kDebugMode)
                  Text('DEBUG MODE', style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11, letterSpacing: 2)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
