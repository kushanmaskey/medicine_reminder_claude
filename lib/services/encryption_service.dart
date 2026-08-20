import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

// AES-256-CBC encryption for sensitive fields stored in Supabase.
// Encrypted values are prefixed with 'enc:' so plain-text legacy data
// is detected and returned as-is (backward compatible).
//
// Key is injected at build time via --dart-define=FIELD_ENCRYPTION_KEY=<32-char>.
// Dev falls back to a fixed key so the app works without the define.
class EncryptionService {
  static const _prefix = 'enc:';

  static const _rawKey = String.fromEnvironment(
    'FIELD_ENCRYPTION_KEY',
    defaultValue: 'MedWallet!Dev#Key2024$Secure@32Ch',
  );

  static late final Encrypter _encrypter;
  static bool _ready = false;

  static void initialize() {
    if (_ready) return;
    final keyBytes = Uint8List.fromList(
      _rawKey.codeUnits.length >= 32
          ? _rawKey.codeUnits.sublist(0, 32)
          : [..._rawKey.codeUnits, ...List.filled(32 - _rawKey.codeUnits.length, 0)],
    );
    _encrypter = Encrypter(AES(Key(keyBytes), mode: AESMode.cbc));
    _ready = true;
  }

  // Encrypts a plain-text value. Returns 'enc:<iv_b64>:<cipher_b64>'.
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;
    initialize();
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(plainText, iv: iv);
    return '$_prefix${base64.encode(iv.bytes)}:${encrypted.base64}';
  }

  // Decrypts a value. If it doesn't start with 'enc:' returns it unchanged
  // (handles plain-text data saved before encryption was added).
  static String decrypt(String value) {
    if (value.isEmpty || !value.startsWith(_prefix)) return value;
    initialize();
    try {
      final parts = value.substring(_prefix.length).split(':');
      if (parts.length != 2) return value;
      final iv = IV(base64.decode(parts[0]));
      return _encrypter.decrypt64(parts[1], iv: iv);
    } catch (_) {
      return value;
    }
  }
}
