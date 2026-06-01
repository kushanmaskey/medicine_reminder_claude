import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  runApp(const MedicalWalletApp());
  // Initialise notifications after the app renders so it never blocks the UI.
  NotificationService.initialize();
}

class MedicalWalletApp extends StatelessWidget {
  const MedicalWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF501513),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.15),
        ),
        child: child!,
      ),
      home: const _SplashRouter(),
    );
  }
}

class _SplashRouter extends StatelessWidget {
  const _SplashRouter();

  Future<_StartupState> _resolve() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!onboardingDone) return _StartupState.onboarding;

    final results = await Future.wait([
      AuthService.isLoggedIn(),
      AuthService.hasAccount(),
    ]);
    if (results[0]) return _StartupState.home;
    if (results[1]) return _StartupState.login;
    return _StartupState.register;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupState>(
      future: _resolve(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF501513)),
            ),
          );
        }
        return switch (snapshot.data!) {
          _StartupState.onboarding => OnboardingScreen(
              onDone: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const _SplashRouter()),
              ),
            ),
          _StartupState.home     => const HomeScreen(),
          _StartupState.login    => const LoginScreen(),
          _StartupState.register => const RegisterScreen(),
        };
      },
    );
  }
}

enum _StartupState { onboarding, home, login, register }
