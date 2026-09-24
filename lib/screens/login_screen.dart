import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/legal_links.dart';

/// The welcome/login screen — the very first thing an unauthenticated
/// player sees (see `main.dart`'s auth gate). Google is the steered-toward
/// path (works immediately, no email infrastructure needed); guest play
/// (`AuthService.signInAsGuest`) is the fallback for anyone who'd rather
/// not sign in with an account at all. Email/password exists in
/// [AuthService] but is deliberately not offered here — see
/// `lib/utils/auth_config.dart`'s `kEmailPasswordSignInEnabled`.
///
/// Visual design: `assets/icons/login_screen_mascot.jpeg` as the
/// full-screen background artwork (unmodified — this screen only lays UI
/// on top of it, never redraws or replaces it), with a small
/// `mascot_transparent.png` badge next to the title.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submitGoogle() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Warns before actually creating the guest account — signing out of a
  /// guest account **deletes it immediately** (see `home_screen.dart`'s
  /// `_handleSignOutTap`), rather than merely being unreachable, and an
  /// account left inactive for 30 days is auto-deleted regardless, the
  /// same as every account (`SUPABASE_SECURITY.md`). Better to say so
  /// upfront than let it be a surprise later at the sign-out button.
  Future<void> _submitGuest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Play as Guest?'),
        content: const Text(
          'Guest progress is temporary — signing out deletes it '
          "immediately, and there's no email or password to sign back in "
          'with. Guest accounts left inactive for 30 days are also '
          'deleted automatically, the same as every account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue as Guest'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await AuthService.signInAsGuest();
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e is StateError ? e.message : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The supplied artwork, unmodified, filling the whole screen —
          // this image's own proportions are close to a phone screen's,
          // so BoxFit.cover only trims a little off the sides rather than
          // cropping into the mascot itself.
          Positioned.fill(
            child: Image.asset(
              'assets/icons/login_screen_mascot.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          // A soft scrim over the very bottom, behind the glass panel —
          // this image's own bottom section (mountains/books) is busier
          // and lighter than its night-sky top, and the panel's own
          // translucency wasn't quite enough contrast without it.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.55, 1],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  _TopBranding(),
                  // Pushes the panel toward the lower part of the screen,
                  // clear of the mascot in the background artwork above.
                  const Spacer(),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.wrong),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  _AuthGlassPanel(
                    isSubmitting: _isSubmitting,
                    onGoogle: _submitGoogle,
                    onGuest: _submitGuest,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Ready to chant your brain Mantra?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small logo + "Brain Mantra" title + subtitle, top-of-screen — held in
/// its own translucent "band" rather than floating directly over the
/// background artwork. Plain text with a drop shadow (the first version
/// of this screen) wasn't reliably legible against this particular
/// illustration's busiest area (stars, the ringed planet, a shooting
/// star), so the band gives it a consistent, readable surface no matter
/// what's directly behind it.
class _TopBranding extends StatelessWidget {
  const _TopBranding();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/icons/mascot_transparent.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Brain Mantra',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      'Let your brain do the Magic',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The compact glassmorphism authentication panel: Google button, an "OR"
/// divider, Guest button, and the legal links — all in one semi-
/// transparent, blurred, rounded card so the background artwork stays
/// visible around and through it.
class _AuthGlassPanel extends StatelessWidget {
  const _AuthGlassPanel({
    required this.isSubmitting,
    required this.onGoogle,
    required this.onGuest,
  });

  final bool isSubmitting;
  final VoidCallback onGoogle;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            // White/lavender, semi-transparent — the artwork behind still
            // shows through, this just softens/frosts it rather than
            // hiding it under an opaque card.
            color: const Color(0xFFF4F0FF).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GoogleButton(onPressed: isSubmitting ? null : onGoogle),
              const SizedBox(height: AppSpacing.md),
              const _OrDivider(),
              const SizedBox(height: AppSpacing.md),
              _GuestButton(onPressed: isSubmitting ? null : onGuest),
              const SizedBox(height: AppSpacing.md),
              const LegalLinksRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.submitButtonText,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/google_icon.png',
              width: 22,
              height: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'Continue with Google',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppColors.submitButtonText.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestButton extends StatelessWidget {
  const _GuestButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.submitButtonText,
          side: BorderSide(
            color: AppColors.submitButtonText.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Continue as Guest',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final lineColor = AppColors.submitButtonText.withValues(alpha: 0.2);
    return Row(
      children: [
        Expanded(child: Divider(color: lineColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            'OR',
            style: TextStyle(
              color: AppColors.submitButtonText.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Divider(color: lineColor)),
      ],
    );
  }
}
