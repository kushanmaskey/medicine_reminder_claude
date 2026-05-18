import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient get _db => Supabase.instance.client;

  static String? get currentUserId => _db.auth.currentUser?.id;

  // ── Auth ─────────────────────────────────────────────────────────────────

  /// Returns null on success, or an error message string on failure.
  static Future<String?> register(
      String email, String password, String name, String sex) async {
    try {
      await _db.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'sex': sex},
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Registration failed. Please try again.';
    }
  }

  static Future<bool> login(String email, String password) async {
    try {
      final res = await _db.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res.session != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> logout() async {
    await _db.auth.signOut();
  }

  static Future<bool> isLoggedIn() async {
    return _db.auth.currentSession != null;
  }

  static Future<bool> hasAccount() async {
    return _db.auth.currentSession != null;
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  static Future<String?> getName() async {
    final id = currentUserId;
    if (id == null) return null;
    try {
      final row = await _db
          .from('profiles')
          .select('name')
          .eq('id', id)
          .maybeSingle();
      return row?['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getSex() async {
    final id = currentUserId;
    if (id == null) return null;
    try {
      final row = await _db
          .from('profiles')
          .select('sex')
          .eq('id', id)
          .maybeSingle();
      return row?['sex'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateName(String name) async {
    final id = currentUserId;
    if (id == null) return;
    await _db.from('profiles').update({'name': name}).eq('id', id);
  }

  static Future<void> updateSex(String sex) async {
    final id = currentUserId;
    if (id == null) return;
    await _db.from('profiles').update({'sex': sex}).eq('id', id);
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  static Future<void> setDefaultAvatar(int index) async {
    final id = currentUserId;
    if (id == null) return;
    await _db.from('profiles').update({
      'avatar_type': 'default',
      'avatar_index': index,
      'avatar_image': null,
    }).eq('id', id);
  }

  static Future<void> setCustomAvatar(String base64Image) async {
    final id = currentUserId;
    if (id == null) return;
    await _db.from('profiles').update({
      'avatar_type': 'custom',
      'avatar_image': base64Image,
      'avatar_index': null,
    }).eq('id', id);
  }

  static Future<Map<String, dynamic>> getAvatarData() async {
    final id = currentUserId;
    if (id == null) return {};
    try {
      final row = await _db
          .from('profiles')
          .select('avatar_type, avatar_index, avatar_image')
          .eq('id', id)
          .maybeSingle();
      if (row == null) return {};
      return {
        'type': row['avatar_type'],
        'index': row['avatar_index'],
        'image': row['avatar_image'],
      };
    } catch (_) {
      return {};
    }
  }

  // No-op kept so main.dart compiles without changes
  static Future<void> migrateIfNeeded() async {}
}
