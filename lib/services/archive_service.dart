import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class ArchiveService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String? get _uid => AuthService.currentUserId;

  // In test mode the cutoff is 1 day ago so you can archive recent records.
  // In production mode the cutoff is 12 months ago.
  static DateTime _cutoff({bool testMode = false}) {
    final now = DateTime.now().toUtc();
    return testMode
        ? now.subtract(const Duration(days: 1))
        : DateTime(now.year - 1, now.month, now.day);
  }

  /// Runs the archive process.
  ///
  /// 1. Fetches all records older than the cutoff from Supabase.
  /// 2. Writes them as JSON files inside a ZIP.
  /// 3. Saves the ZIP to the device's documents directory.
  /// 4. Deletes the archived records from Supabase.
  ///
  /// Returns the path to the saved ZIP file, or throws on error.
  static Future<String> runArchive({bool testMode = false}) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not logged in');

    final cutoff = _cutoff(testMode: testMode);
    final cutoffStr = cutoff.toIso8601String();
    final label = testMode ? 'test' : 'yearly';
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-').substring(0, 19);

    // ── Fetch old records ─────────────────────────────────────────────────────

    final tables = {
      'vitals':        'recorded_at',
      'activities':    'recorded_at',
      'appointments':  'appointment_date_time',
      'prescriptions': 'created_at',
      'allergies':     'created_at',
      'insurance':     'created_at',
    };

    final Map<String, List<Map<String, dynamic>>> archived = {};
    final Map<String, List<String>> archivedIds = {};

    for (final entry in tables.entries) {
      final table = entry.key;
      final dateCol = entry.value;
      final rows = await _db
          .from(table)
          .select()
          .eq('user_id', uid)
          .lt(dateCol, cutoffStr);

      if (rows.isNotEmpty) {
        archived[table] = List<Map<String, dynamic>>.from(rows);
        archivedIds[table] = rows.map((r) => r['id'] as String).toList();
      }
    }

    if (archived.isEmpty) {
      throw Exception('No records found older than the cutoff date (${cutoff.toLocal().toString().substring(0, 10)}).');
    }

    // ── Build ZIP ─────────────────────────────────────────────────────────────

    final encoder = ZipFileEncoder();
    final dir = await getApplicationDocumentsDirectory();
    final zipPath = '${dir.path}/medical_wallet_archive_${label}_$timestamp.zip';

    encoder.create(zipPath);

    final meta = {
      'archive_type': label,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'cutoff_date': cutoff.toIso8601String(),
      'user_id': uid,
      'record_counts': archived.map((k, v) => MapEntry(k, v.length)),
    };
    encoder.addArchiveFile(ArchiveFile(
      'metadata.json',
      utf8.encode(const JsonEncoder.withIndent('  ').convert(meta)).length,
      utf8.encode(const JsonEncoder.withIndent('  ').convert(meta)),
    ));

    for (final entry in archived.entries) {
      final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(entry.value));
      encoder.addArchiveFile(ArchiveFile('${entry.key}.json', bytes.length, bytes));
    }

    encoder.close();

    // ── Delete archived records from Supabase ─────────────────────────────────

    for (final entry in archivedIds.entries) {
      final table = entry.key;
      final ids = entry.value;
      // Delete in batches of 100 to avoid query limits
      for (var i = 0; i < ids.length; i += 100) {
        final batch = ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
        await _db.from(table).delete().eq('user_id', uid).inFilter('id', batch);
      }
    }

    return zipPath;
  }

  /// Summary of how many records would be archived without doing it.
  static Future<Map<String, int>> preview({bool testMode = false}) async {
    final uid = _uid;
    if (uid == null) return {};

    final cutoff = _cutoff(testMode: testMode);
    final cutoffStr = cutoff.toIso8601String();

    final tables = {
      'vitals':        'recorded_at',
      'activities':    'recorded_at',
      'appointments':  'appointment_date_time',
      'prescriptions': 'created_at',
      'allergies':     'created_at',
      'insurance':     'created_at',
    };

    final counts = <String, int>{};
    for (final entry in tables.entries) {
      final rows = await _db
          .from(entry.key)
          .select('id')
          .eq('user_id', uid)
          .lt(entry.value, cutoffStr);
      if (rows.isNotEmpty) counts[entry.key] = rows.length;
    }
    return counts;
  }
}
