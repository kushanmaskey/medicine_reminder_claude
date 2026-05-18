import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RingtoneService {
  static const _channel = MethodChannel('com.medreminder/ringtone');
  static const _keyUri = 'notification_sound_uri';
  static const _keyName = 'notification_sound_name';

  static Future<Map<String, String?>> pickRingtone() async {
    try {
      final currentUri = await getSoundUri();
      final uri = await _channel.invokeMethod<String>('pickRingtone', {
        'currentUri': currentUri,
      });
      if (uri == null) return {'uri': null, 'name': null};
      final name = await _getRingtoneName(uri);
      return {'uri': uri, 'name': name};
    } on PlatformException {
      return {'uri': null, 'name': null};
    }
  }

  static Future<String?> _getRingtoneName(String uri) async {
    try {
      return await _channel.invokeMethod<String>('getRingtoneName', {'uri': uri});
    } on PlatformException {
      return null;
    }
  }

  static Future<void> saveSound(String uri, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUri, uri);
    await prefs.setString(_keyName, name ?? 'Custom Sound');
  }

  static Future<void> clearSound() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUri);
    await prefs.remove(_keyName);
  }

  static Future<String?> getSoundUri() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUri);
  }

  static Future<String?> getSoundName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }
}
