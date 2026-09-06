import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/supabase_config.dart';
import 'utils/constants.dart';

/// Entry point. Connects to Supabase before anything else runs — every
/// screen assumes `Supabase.instance.client` is already initialized.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // Legacy JWT-format anon keys (like this project's) remain valid —
    // they're just passed under the SDK's newer parameter name now.
    publishableKey: SupabaseConfig.anonKey,
  );
  runApp(const MathBlitzApp());
}

class MathBlitzApp extends StatelessWidget {
  const MathBlitzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MathBlitz',
      theme: _buildTheme(),
      home: const _AuthGate(),
    );
  }

  /// Light blue + silver theme — chosen to be easier on the eyes over long
  /// play sessions than the original off-white/plain-Material look.
  /// AppColors.background/silver are the two colors that actually matter
  /// here; the rest of the seeded scheme just keeps buttons/inputs/etc.
  /// visually consistent with them.
  ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.background,
      primary: AppColors.primary,
      surface: AppColors.silver,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

/// Decides between the login/sign-up flow and [HomeScreen] based on
/// whether a Supabase session exists — including on a fresh app launch,
/// since `supabase_flutter` persists sessions locally by default (this is
/// what keeps a signed-up player logged in until they actually sign out).
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Separate from the StreamBuilder below — this is purely the
    // one-time-per-sign-in side effect (creating a profiles row), kept
    // out of build() so it never runs as a side effect of rebuilding.
    _authSubscription = AuthService.authStateChanges.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        AuthService.ensureProfileExists();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService.authStateChanges,
      builder: (context, _) {
        final hasSession = AuthService.currentUser != null;
        return hasSession ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
