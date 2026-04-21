import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter email and password.'); return;
    }
    final emailOk = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!emailOk) {
      setState(() => _error = 'Please enter a valid email address.'); return;
    }
    setState(() { _loading = true; _error = null; });
    final ok = await context.read<AuthProvider>().login(email, pass);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      _routeAfterLogin();
    } else {
      setState(() => _error = context.read<AuthProvider>().error ?? 'Login failed.');
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    final ok = await context.read<AuthProvider>().signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      _routeAfterLogin();
    } else if (context.read<AuthProvider>().error != null) {
      setState(() => _error = context.read<AuthProvider>().error);
    }
  }

  Future<void> _loginWithApple() async {
    setState(() { _loading = true; _error = null; });
    final ok = await context.read<AuthProvider>().signInWithApple();
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      _routeAfterLogin();
    } else if (context.read<AuthProvider>().error != null) {
      setState(() => _error = context.read<AuthProvider>().error);
    }
  }

  void _routeAfterLogin() {
    final role = context.read<AuthProvider>().userRole;
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 40),
          // Logo
          Center(child: Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Center(child: Text('✈', style: TextStyle(fontSize: 36))))),
          const SizedBox(height: 32),
          const Text('Welcome back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Sign in to your account', style: TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 32),

          // Error
          if (_error != null) Container(
            padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200)),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
            ])),

          // Email
          const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          AppTextField(hint: 'Enter your email', controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),

          // Password
          const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          AppTextField(hint: 'Enter your password', controller: _passCtrl, obscureText: _obscure,
            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure))),

          Align(alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(AppRoutes.forgotPassword),
              child: const Text('Forgot password?', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600)))),
          const SizedBox(height: 8),

          // Login button
          PrimaryButton(label: 'Login', isLoading: _loading, onTap: _login),
          const SizedBox(height: 24),

          // Divider
          Row(children: [
            const Expanded(child: Divider()),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Or continue with', style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 16),

          // Social buttons
          Row(children: [
            Expanded(child: SocialLoginButton(
              icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4285F4))),
              onTap: _loading ? null : _loginWithGoogle,
            )),
            const SizedBox(width: 12),
            Expanded(child: SocialLoginButton(
              icon: const Icon(Icons.apple, size: 20),
              onTap: _loading ? null : _loginWithApple,
            )),
          ]),
          const SizedBox(height: 32),

          // Sign up
          Center(child: GestureDetector(
            onTap: () => context.go(AppRoutes.signup),
            child: RichText(text: const TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.grey),
              children: [
                TextSpan(text: "Don't have an account? "),
                TextSpan(text: 'Sign Up', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold)),
              ])))),
        ]),
      )),
    );
  }
}
