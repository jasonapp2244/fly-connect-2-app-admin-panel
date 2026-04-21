import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await context.read<AuthProvider>().resetPassword(email);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (ok) {
        _sent = true;
      } else {
        _error = context.read<AuthProvider>().error ??
            'Failed to send reset email.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _sent ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset_rounded,
                size: 36, color: AppColors.dark),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Forgot Password?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          "Enter your email and we'll send you a link to reset your password.",
          style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 32),

        // Error
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ]),
          ),

        const Text('Email',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        AppTextField(
          hint: 'Enter your registered email',
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.email_outlined, size: 20),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Send Reset Link',
          isLoading: _loading,
          onTap: _sendResetEmail,
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => context.go(AppRoutes.login),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 14, color: Colors.grey),
                children: [
                  TextSpan(text: 'Remember your password? '),
                  TextSpan(
                      text: 'Sign In',
                      style: TextStyle(
                          color: AppColors.dark, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.online.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              size: 48, color: AppColors.online),
        ),
        const SizedBox(height: 28),
        const Text('Check your email',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(
          "We sent a password reset link to\n${_emailCtrl.text.trim()}",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline,
                size: 18, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Didn't receive the email? Check your spam folder or try again.",
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Back to Login',
            onTap: () => context.go(AppRoutes.login),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _sent = false;
              _error = null;
            });
          },
          child: const Text('Resend email',
              style: TextStyle(
                  color: AppColors.dark, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
