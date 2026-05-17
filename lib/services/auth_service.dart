import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyEmail = 'user_email';
  static const _keyPassword = 'user_password';
  static const _keyLoggedIn = 'is_logged_in';
  static const _keyName = 'user_name';
  static const _keySex = 'user_sex';

  static String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  static Future<bool> hasAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail) != null;
  }

  static Future<void> register(
      String email, String password, String name, String sex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyPassword, _hash(password));
    await prefs.setString(_keyName, name);
    await prefs.setString(_keySex, sex);
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

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  static const _keyAvatarType = 'avatar_type';
  static const _keyAvatarIndex = 'avatar_index';
  static const _keyAvatarImage = 'avatar_image';

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  static Future<String?> getSex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySex);
  }

  static Future<void> updateName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
  }

  static Future<void> setDefaultAvatar(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatarType, 'default');
    await prefs.setInt(_keyAvatarIndex, index);
    await prefs.remove(_keyAvatarImage);
  }

  static Future<void> setCustomAvatar(String base64Image) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatarType, 'custom');
    await prefs.setString(_keyAvatarImage, base64Image);
    await prefs.remove(_keyAvatarIndex);
  }

  static Future<Map<String, dynamic>> getAvatarData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'type': prefs.getString(_keyAvatarType),
      'index': prefs.getInt(_keyAvatarIndex),
      'image': prefs.getString(_keyAvatarImage),
    };
  }
}
