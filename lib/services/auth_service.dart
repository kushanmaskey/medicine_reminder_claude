import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient get _db => Supabase.instance.client;

  static String? get currentUserId => _db.auth.currentUser?.id;

  // ── Auth ─────────────────────────────────────────────────────────────────

  /// Returns null on success, or an error message string on failure.
  static Future<String?> register(
      String email, String password, String name, String sex, String phone) async {
    try {
      final res = await _db.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'sex': sex, 'phone': phone},
        emailRedirectTo: 'com.medreminder.medicationreminder://login-callback/',
      );

      // Email confirmation disabled — session exists, create profile now
      if (res.session != null && res.user != null) {
        await _db.from('profiles').upsert({
          'id': res.user!.id,
          'name': name,
          'sex': sex,
          'phone': phone,
        });
      }
      // Email confirmation enabled — session is null.
      // Profile will be created on first login via _ensureProfile using stored metadata.
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Registration failed: $e';
    }
  }

  /// Returns null on success, or an error message on failure.
  static Future<String?> login(String email, String password) async {
    try {
      final res = await _db.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.session == null) return 'Invalid email or password.';
      await _ensureProfile(res.user!.id);
      return null;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('email not confirmed') || msg.contains('not confirmed')) {
        return 'Please verify your email before signing in. Check your inbox.';
      }
      return 'Invalid email or password.';
    } catch (_) {
      return 'Invalid email or password.';
    }
  }

  static Future<void> _ensureProfile(String userId) async {
    try {
      final existing = await _db.from('profiles').select('id').eq('id', userId).maybeSingle();
      if (existing != null) return;
      final meta = _db.auth.currentUser?.userMetadata ?? {};
      await _db.from('profiles').upsert({
        'id': userId,
        'name': meta['name'] ?? '',
        'sex': meta['sex'] ?? 'Male',
        'phone': meta['phone'] ?? '',
      });
    } catch (_) {}
  }

  static Future<void> logout() async {
    await _db.auth.signOut();
  }

  static Future<String?> resetPassword(String email) async {
    try {
      await _db.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.medreminder.medicationreminder://login-callback/',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to send reset email. Please try again.';
    }
  }

  static Future<String?> updatePassword(String newPassword) async {
    try {
      await _db.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to update password. Please try again.';
    }
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

  static Future<String?> getPhone() async {
    final id = currentUserId;
    if (id == null) return null;
    try {
      final row = await _db
          .from('profiles')
          .select('phone')
          .eq('id', id)
          .maybeSingle();
      return row?['phone'] as String?;
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
