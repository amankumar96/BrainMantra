import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/auth_config.dart';
import '../utils/constants.dart';
import '../utils/legal_links.dart';
import '../widgets/brand_header.dart';
import '../widgets/math_background_decoration.dart';
import 'login_screen.dart';

/// Account creation. Google is the steered-toward path — it's the first,
/// most prominent action on screen, never involves email confirmation, and
/// (while [kEmailPasswordSignInEnabled] is off — see that flag's doc
/// comment) currently the *only* path shown. Email/password sign-up is
/// fully implemented below but hidden for now; with "Confirm email" turned
/// on for this project, a successful email sign-up doesn't log the player
/// in — it sends a confirmation link, and this screen switches to a "check
/// your email" state until they click it and come back to log in. (The
/// root auth-gate in main.dart reacts to a session becoming active and
/// swaps to HomeScreen on its own; this screen never navigates there
/// itself.)
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  /// Non-null once an email sign-up has sent a confirmation link — holds
  /// the address it was sent to, and switches the body over to the
  /// "check your email" view instead of the form.
  String? _confirmationSentTo;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final email = _emailController.text.trim();
      final result = await AuthService.signUp(
        email: email,
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
      );
      if (result == SignUpResult.confirmationEmailSent && mounted) {
        setState(() => _confirmationSentTo = email);
      }
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
      // No AppBar — replaced by BrandHeader below, matching Home's (and
      // Login's) own gradient banner.
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const BrandHeader(tagline: 'Join thousands sharpening their mind'),
          Expanded(
            child: Stack(
              children: [
                // Same soft-blue AppColors.background as before, just no
                // longer flat — see LoginScreen for the identical
                // treatment this was copied from.
                const Positioned.fill(child: MathBackgroundDecoration()),
                SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
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
                                color:
                                    AppColors.primary.withValues(alpha: 0.10),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _confirmationSentTo != null
                              ? _buildConfirmationPending(
                                  _confirmationSentTo!,
                                )
                              : _buildForm(),
                        ),
                      ],
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

  Widget _buildConfirmationPending(String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.primary),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "We've sent a confirmation link to $email. Click it, then log in "
          'below.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          child: const Text('Back to Log In'),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
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
          // Google first and most prominent — it's the path most players
          // should take, and it never needs email confirmation.
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submitGoogle,
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('Continue with Google', style: TextStyle(fontSize: 16)),
            ),
          ),
          if (kEmailPasswordSignInEnabled) ...[
            const SizedBox(height: AppSpacing.lg),
            const Row(
              children: [
                Expanded(child: Divider(color: AppColors.silver)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text('or sign up with email'),
                ),
                Expanded(child: Divider(color: AppColors.silver)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a display name'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) => (value == null || !value.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (value) => (value == null || value.length < 6)
                  ? 'At least 6 characters'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              "We'll email you a confirmation link — you'll need to click "
              "it before you can log in.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            kEmailPasswordSignInEnabled
                ? 'By signing up or continuing with Google, you agree to our:'
                : 'By continuing with Google, you agree to our:',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const LegalLinksRow(),
          if (kEmailPasswordSignInEnabled) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: _isSubmitting ? null : _submitEmailSignUp,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign Up with Email'),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Already have an account? Log in'),
            ),
          ],
        ],
      ),
    );
  }
}
