import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyEmail = 'user_email';
  static const _keyPassword = 'user_password';
  static const _keyLoggedIn = 'is_logged_in';

  static String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  static Future<bool> register(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyEmail);
    if (existing != null) return false;
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyPassword, _hash(password));
    return true;
  }

  static Future<bool> login(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString(_keyEmail);
    var storedPassword = prefs.getString(_keyPassword);
    if (storedEmail == null || storedPassword == null) return false;

    // Migrate plaintext passwords to hashed on first login after update.
    // SHA-256 hex strings are always 64 chars; shorter means plaintext.
    if (storedPassword.length != 64) {
      if (storedEmail == email && storedPassword == password) {
        final hashed = _hash(password);
        await prefs.setString(_keyPassword, hashed);
        storedPassword = hashed;
      } else {
        return false;
      }
    }

    if (storedEmail == email && storedPassword == _hash(password)) {
      await prefs.setBool(_keyLoggedIn, true);
      return true;
    }
    return false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, false);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) ?? false;
  }

  static Future<bool> hasAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail) != null;
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }
}
