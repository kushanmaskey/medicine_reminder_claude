import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final _auth = LocalAuthentication();
  static const _prefKey = 'biometric_enabled';

  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics.timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
      if (canCheck) return true;
      // Fallback for iOS 15+ where canCheckBiometrics can return false
      // even when Face ID / Touch ID hardware is present and enrolled.
      final biometrics = await _auth.getAvailableBiometrics().timeout(
        const Duration(seconds: 3),
        onTimeout: () => [],
      );
      return biometrics.isNotEmpty;
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
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return (success, null);
    } on PlatformException catch (e) {
      return (false, _errorMessage(e.code));
    } catch (_) {
      return (false, null);
    }
  }

  static String _errorMessage(String code) {
    switch (code.toLowerCase()) {
      case 'notavailable':
        return 'Biometric authentication is not available on this device.';
      case 'notenrolled':
        return 'No biometrics enrolled. Set up fingerprint or face unlock in device Settings first.';
      case 'lockedout':
        return 'Too many failed attempts. Please try again later or use your password.';
      case 'permanentlylockedout':
        return 'Biometrics are permanently locked. Unlock your device with your PIN first.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }
}
