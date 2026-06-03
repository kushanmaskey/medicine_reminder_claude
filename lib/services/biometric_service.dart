import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final _auth = LocalAuthentication();
  static const _prefKey = 'biometric_enabled';

  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      // canCheckBiometrics is more reliable than getAvailableBiometrics on Android
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  static Future<bool> authenticate({
    String reason = 'Authenticate to access My Medical Wallet',
  }) async {
    final (success, _) = await authenticateWithError(reason: reason);
    return success;
  }

  static Future<(bool, String?)> authenticateWithError({
    String reason = 'Authenticate to access My Medical Wallet',
  }) async {
    try {
      final success = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return (success, null);
    } on PlatformException catch (e) {
      return (false, _errorMessage(e.code));
    } catch (_) {
      return (false, null);
    }
  }

  static String _errorMessage(String code) => switch (code) {
    'NotAvailable' =>
      'Biometric authentication is not available on this device.',
    'NotEnrolled' =>
      'No biometrics enrolled. Set up fingerprint or face unlock in device Settings first.',
    'LockedOut' =>
      'Too many failed attempts. Please try again later or use your password.',
    'PermanentlyLockedOut' =>
      'Biometrics are permanently locked. Unlock your device with your PIN first.',
    _ => 'Authentication error ($code). Please try again.',
  };
}
