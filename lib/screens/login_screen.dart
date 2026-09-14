import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'sign_up_screen.dart';

/// Returning-player login. Google is the steered-toward path — it's the
/// first, most prominent action on screen. Email/password is offered as a
/// secondary option below it; a login attempt on an account that hasn't
/// clicked its confirmation email yet gets a friendly explanation instead
/// of Supabase's raw error text. Like SignUpScreen, this screen doesn't
/// navigate anywhere on success itself — the root auth-gate in main.dart
/// reacts to the session becoming active and swaps to HomeScreen
/// automatically.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final isUnconfirmed = e.code == 'email_not_confirmed' ||
          e.message.toLowerCase().contains('not confirmed');
      setState(() => _errorMessage = isUnconfirmed
          ? "Almost there — click the confirmation link we emailed you "
              'before logging in.'
          : e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() => _errorMessage = null);
    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Brain Mantra')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.wrong),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                // Google first and most prominent — it's the path most
                // players should take, and it never needs email
                // confirmation.
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child:
                        Text('Continue with Google', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.silver)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Text('or log in with email'),
                    ),
                    Expanded(child: Divider(color: AppColors.silver)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      (value == null || !value.contains('@'))
                          ? 'Enter a valid email'
                          : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter your password'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: _isSubmitting ? null : _submitEmailLogin,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log In with Email'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  ),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
