import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

const _gradient = LinearGradient(
  colors: [Color(0xFF501513), Color(0xFF7A2420)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class BiometricLockScreen extends StatefulWidget {
  /// When true, a successful unlock replaces the current route with HomeScreen.
  /// When false (pushed over HomeScreen), pop with `true` on success.
  final bool replaceWithHome;

  const BiometricLockScreen({super.key, this.replaceWithHome = false});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _authenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() {
      _authenticating = true;
      _errorMessage = null;
    });
    final (success, error) = await BiometricService.authenticateWithError()
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => (false, 'Authentication timed out. Please try again.'),
        );
    if (!mounted) return;
    if (success) {
      await _unlock();
    } else {
      setState(() {
        _authenticating = false;
        _errorMessage = error ??
            'Authentication failed. Tap "Use Biometrics" to try again, or use your password to sign in.';
      });
    }
  }

  // Reset session timer so HomeScreen doesn't immediately expire and
  // prompt for biometrics a second time.
  Future<void> _unlock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('session_login_time', DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    if (widget.replaceWithHome) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _usePassword() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: _gradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF501513).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'My Medical Wallet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Authenticate to access your health data',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 48),
              if (_authenticating)
                const CircularProgressIndicator(color: Color(0xFF501513))
              else ...[
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _gradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF501513).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _authenticate,
                        borderRadius: BorderRadius.circular(14),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fingerprint, color: Colors.white, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'Use Biometrics',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _usePassword,
                  child: const Text(
                    'Use Password Instead',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
