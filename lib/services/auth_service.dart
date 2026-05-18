import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Global keys (not per-user)
  static const _keyAccounts = 'accounts';
  static const _keyCurrentUserId = 'current_user_id';
  static const _keyIsLoggedIn = 'is_logged_in';

  // In-memory cache of the logged-in user's ID
  static String? _currentUserId;

  static String? get currentUserId => _currentUserId;

  // Derive a stable 16-char hex ID from an email address
  static String _userId(String email) =>
      sha256.convert(utf8.encode(email.toLowerCase().trim())).toString().substring(0, 16);

  static String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  // ── Accounts list helpers ────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyAccounts);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  static Future<void> _saveAccounts(List<Map<String, dynamic>> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccounts, jsonEncode(accounts));
  }

  // ── Public API ───────────────────────────────────────────────────────────

  static Future<bool> hasAccount() async {
    final accounts = await _getAccounts();
    return accounts.isNotEmpty;
  }

  static Future<bool> emailExists(String email) async {
    final accounts = await _getAccounts();
    final id = _userId(email);
    return accounts.any((a) => a['id'] == id);
  }

  static Future<void> register(
      String email, String password, String name, String sex) async {
    final id = _userId(email);
    final accounts = await _getAccounts();
    // Remove any existing entry for this email before adding fresh
    accounts.removeWhere((a) => a['id'] == id);
    accounts.add({
      'id': id,
      'email': email.toLowerCase().trim(),
      'password': _hash(password),
      'name': name,
      'sex': sex,
    });
    await _saveAccounts(accounts);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$id:user_name', name);
    await prefs.setString('$id:user_sex', sex);
  }

  static Future<bool> login(String email, String password) async {
    final accounts = await _getAccounts();
    final id = _userId(email);
    final matches = accounts.where((a) => a['id'] == id).toList();
    if (matches.isEmpty) return false;
    final account = matches.first;

    final storedPassword = account['password'] as String? ?? '';

    // Migrate plaintext passwords (length != 64 means not yet hashed)
    String verified = storedPassword;
    if (storedPassword.length != 64) {
      if (storedPassword != password) return false;
      verified = _hash(password);
      account['password'] = verified;
      await _saveAccounts(accounts);
    }

    if (verified != _hash(password)) return false;

    _currentUserId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUserId, id);
    await prefs.setBool(_keyIsLoggedIn, true);
    return true;
  }

  static Future<void> logout() async {
    _currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyCurrentUserId);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    if (loggedIn) {
      _currentUserId = prefs.getString(_keyCurrentUserId);
      return _currentUserId != null;
    }
    return false;
  }

  // ── Per-user profile ─────────────────────────────────────────────────────

  static Future<String?> getName() async {
    if (_currentUserId == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_currentUserId:user_name');
  }

  static Future<String?> getSex() async {
    if (_currentUserId == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_currentUserId:user_sex');
  }

  static Future<void> updateName(String name) async {
    if (_currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_currentUserId:user_name', name);
    final accounts = await _getAccounts();
    final idx = accounts.indexWhere((a) => a['id'] == _currentUserId);
    if (idx != -1) {
      accounts[idx] = {...accounts[idx], 'name': name};
      await _saveAccounts(accounts);
    }
  }

  static Future<void> updateSex(String sex) async {
    if (_currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_currentUserId:user_sex', sex);
    final accounts = await _getAccounts();
    final idx = accounts.indexWhere((a) => a['id'] == _currentUserId);
    if (idx != -1) {
      accounts[idx] = {...accounts[idx], 'sex': sex};
      await _saveAccounts(accounts);
    }
  }

  // ── Per-user avatar ───────────────────────────────────────────────────────

  static Future<void> setDefaultAvatar(int index) async {
    if (_currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_currentUserId:avatar_type', 'default');
    await prefs.setInt('$_currentUserId:avatar_index', index);
    await prefs.remove('$_currentUserId:avatar_image');
  }

  static Future<void> setCustomAvatar(String base64Image) async {
    if (_currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_currentUserId:avatar_type', 'custom');
    await prefs.setString('$_currentUserId:avatar_image', base64Image);
    await prefs.remove('$_currentUserId:avatar_index');
  }

  static Future<Map<String, dynamic>> getAvatarData() async {
    if (_currentUserId == null) return {};
    final prefs = await SharedPreferences.getInstance();
    return {
      'type': prefs.getString('$_currentUserId:avatar_type'),
      'index': prefs.getInt('$_currentUserId:avatar_index'),
      'image': prefs.getString('$_currentUserId:avatar_image'),
    };
  }

  // ── One-time migration from the old single-user flat key format ──────────

  static Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final oldEmail = prefs.getString('user_email');
    if (oldEmail == null) return; // already migrated or first install

    final accounts = await _getAccounts();
    if (accounts.isEmpty) {
      final id = _userId(oldEmail);
      final oldName = prefs.getString('user_name') ?? '';
      final oldSex = prefs.getString('user_sex') ?? 'Male';
      final oldPassword = prefs.getString('user_password') ?? '';

      accounts.add({
        'id': id,
        'email': oldEmail.toLowerCase().trim(),
        'password': oldPassword,
        'name': oldName,
        'sex': oldSex,
      });
      await _saveAccounts(accounts);

      // Migrate per-user profile keys
      await prefs.setString('$id:user_name', oldName);
      await prefs.setString('$id:user_sex', oldSex);

      // Migrate avatar
      for (final k in ['avatar_type', 'avatar_image']) {
        final v = prefs.getString(k);
        if (v != null) await prefs.setString('$id:$k', v);
      }
      final avatarIndex = prefs.getInt('avatar_index');
      if (avatarIndex != null) await prefs.setInt('$id:avatar_index', avatarIndex);

      // Migrate data lists
      for (final k in [
        'prescriptions',
        'medications',
        'appointments',
        'vitals',
        'activities'
      ]) {
        final list = prefs.getStringList(k);
        if (list != null) await prefs.setStringList('$id:$k', list);
      }

      // Restore session if user was logged in
      if (prefs.getBool('is_logged_in') ?? false) {
        _currentUserId = id;
        await prefs.setString(_keyCurrentUserId, id);
        await prefs.setBool(_keyIsLoggedIn, true);
      }
    }

    // Remove old flat keys
    for (final k in [
      'user_email', 'user_password', 'user_name', 'user_sex',
      'avatar_type', 'avatar_index', 'avatar_image',
      'prescriptions', 'medications', 'appointments', 'vitals', 'activities',
    ]) {
      await prefs.remove(k);
    }
  }
}
