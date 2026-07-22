import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/biometric_lock_screen.dart';
import 'screens/reset_password_screen.dart';
import 'onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    ).timeout(const Duration(seconds: 10));
  } catch (_) {}
  try {
    await NotificationService.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  } catch (_) {}
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    await PurchaseService.initialize(userId).timeout(const Duration(seconds: 10));
  } catch (_) {}
  runApp(const MedicalWalletApp());
}

class MedicalWalletApp extends StatefulWidget {
  const MedicalWalletApp({super.key});

  @override
  State<MedicalWalletApp> createState() => _MedicalWalletAppState();
}

class _MedicalWalletAppState extends State<MedicalWalletApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          (_) => false,
        );
      } else if (data.event == AuthChangeEvent.signedIn) {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Medical Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B6B),
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
    if (results[0]) {
      try {
        final biometricEnabled = await BiometricService.isEnabled();
        if (biometricEnabled) {
          return _StartupState.biometricLock;
        }
      } catch (_) {}
      return _StartupState.home;
    }
    return _StartupState.login;
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
              child: CircularProgressIndicator(color: Color(0xFFFF6B6B)),
            ),
          );
        }
        return switch (snapshot.data!) {
          _StartupState.onboarding => OnboardingScreen(
              onDone: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const _SplashRouter()),
              ),
            ),
          _StartupState.biometricLock => const BiometricLockScreen(replaceWithHome: true),
          _StartupState.home         => const HomeScreen(),
          _StartupState.login        => const LoginScreen(),
        };
      },
    );
  }
}

enum _StartupState { onboarding, biometricLock, home, login }
