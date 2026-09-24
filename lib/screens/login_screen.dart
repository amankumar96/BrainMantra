import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../services/auth_service.dart';
import '../utils/auth_config.dart';
import '../utils/constants.dart';
import '../utils/legal_links.dart';
import '../widgets/brand_header.dart';
import '../widgets/math_background_decoration.dart';
import 'sign_up_screen.dart';

/// Returning-player login. Google is the steered-toward path — it's the
/// first, most prominent action on screen, and (while
/// [kEmailPasswordSignInEnabled] is off — see that flag's doc comment for
/// why) currently the *only* one: email/password is fully implemented
/// below but not shown. A login attempt on an account that hasn't clicked
/// its confirmation email yet gets a friendly explanation instead of
/// Supabase's raw error text. Like SignUpScreen, this screen doesn't
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
      // No AppBar — replaced by BrandHeader below, matching Home's own
      // gradient banner (see class doc).
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const BrandHeader(tagline: 'Welcome back — let\'s keep sharpening'),
          Expanded(
            child: Stack(
              children: [
                // Same soft-blue AppColors.background as before, just no
                // longer flat — the mascot watermark + slowly bobbing math
                // symbols sit behind the card, never behind readable text.
                const Positioned.fill(child: MathBackgroundDecoration()),
                SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.10),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_errorMessage != null) ...[
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.wrong,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                // Google first and most prominent — it's
                                // the path most players should take, and
                                // it never needs email confirmation.
                                FilledButton.icon(
                                  onPressed:
                                      _isSubmitting ? null : _submitGoogle,
                                  icon: const Icon(
                                    Icons.g_mobiledata,
                                    size: 28,
                                  ),
                                  label: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      'Continue with Google',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                                if (kEmailPasswordSignInEnabled) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  const Row(
                                    children: [
                                      Expanded(
                                        child:
                                            Divider(color: AppColors.silver),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                        ),
                                        child: Text('or log in with email'),
                                      ),
                                      Expanded(
                                        child:
                                            Divider(color: AppColors.silver),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) => (value == null ||
                                            !value.contains('@'))
                                        ? 'Enter a valid email'
                                        : null,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  TextFormField(
                                    controller: _passwordController,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                    ),
                                    obscureText: true,
                                    validator: (value) =>
                                        (value == null || value.isEmpty)
                                            ? 'Enter your password'
                                            : null,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  OutlinedButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : _submitEmailLogin,
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Log In with Email'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // The "Sign up" toggle only matters when the
                          // email/password path exists — with Google-only,
                          // Login and Sign-up render identically, and
                          // Google's own flow already creates the account
                          // on first use, so there's nothing new to send a
                          // player to.
                          if (kEmailPasswordSignInEnabled) ...[
                            const SizedBox(height: AppSpacing.lg),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const SignUpScreen(),
                                ),
                              ),
                              child: const Text(
                                "Don't have an account? Sign up",
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          const LegalLinksRow(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
