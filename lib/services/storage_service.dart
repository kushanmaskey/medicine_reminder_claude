import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prescription.dart';
import '../models/medication.dart';
import '../models/appointment.dart';
import '../models/vital.dart';
import '../models/activity.dart';
import 'auth_service.dart';

class StorageService {
  static const _keyPrescriptions = 'prescriptions';
  static const _keyMedications = 'medications';
  static const _keyAppointments = 'appointments';
  static const _keyVitals = 'vitals';
  static const _keyActivities = 'activities';

  // Prefix every key with the current user's ID
  static String _p(String key) {
    final id = AuthService.currentUserId;
    assert(id != null, 'StorageService called with no logged-in user');
    return '${id!}:$key';
  }

  // Clears only the current user's health data (not their account credentials)
  static Future<void> clearCurrentUserData() async {
    final id = AuthService.currentUserId;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      _keyPrescriptions, _keyMedications, _keyAppointments,
      _keyVitals, _keyActivities,
      'avatar_type', 'avatar_index', 'avatar_image',
      'user_name', 'user_sex',
    ]) {
      await prefs.remove('$id:$k');
    }
  }

  // ── Prescriptions ─────────────────────────────────────────────────────────

  static Future<List<Prescription>> getPrescriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_p(_keyPrescriptions)) ?? [];
    return raw.map((s) => Prescription.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> savePrescription(Prescription prescription) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyPrescriptions)) ?? [];
    list.add(jsonEncode(prescription.toJson()));
    await prefs.setStringList(_p(_keyPrescriptions), list);
  }

  static Future<void> updatePrescription(Prescription prescription) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyPrescriptions)) ?? [];
    final idx = list.indexWhere((s) =>
        (jsonDecode(s) as Map<String, dynamic>)['id'] == prescription.id);
    if (idx != -1) {
      list[idx] = jsonEncode(prescription.toJson());
      await prefs.setStringList(_p(_keyPrescriptions), list);
    }
  }

  static Future<void> deletePrescription(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyPrescriptions)) ?? [];
    list.removeWhere(
        (s) => (jsonDecode(s) as Map<String, dynamic>)['id'] == id);
    await prefs.setStringList(_p(_keyPrescriptions), list);
  }

  // ── Medications ───────────────────────────────────────────────────────────

  static Future<List<Medication>> getMedications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_p(_keyMedications)) ?? [];
    return raw.map((s) => Medication.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> saveMedication(Medication medication) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyMedications)) ?? [];
    list.add(jsonEncode(medication.toJson()));
    await prefs.setStringList(_p(_keyMedications), list);
  }

  static Future<void> deleteMedication(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyMedications)) ?? [];
    list.removeWhere(
        (s) => (jsonDecode(s) as Map<String, dynamic>)['id'] == id);
    await prefs.setStringList(_p(_keyMedications), list);
  }

  // ── Appointments ──────────────────────────────────────────────────────────

  static Future<List<Appointment>> getAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_p(_keyAppointments)) ?? [];
    return raw.map((s) => Appointment.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> saveAppointment(Appointment appointment) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyAppointments)) ?? [];
    list.add(jsonEncode(appointment.toJson()));
    await prefs.setStringList(_p(_keyAppointments), list);
  }

  static Future<void> updateAppointment(Appointment appointment) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyAppointments)) ?? [];
    final idx = list.indexWhere((s) =>
        (jsonDecode(s) as Map<String, dynamic>)['id'] == appointment.id);
    if (idx != -1) {
      list[idx] = jsonEncode(appointment.toJson());
      await prefs.setStringList(_p(_keyAppointments), list);
    }
  }

  static Future<void> deleteAppointment(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyAppointments)) ?? [];
    list.removeWhere(
        (s) => (jsonDecode(s) as Map<String, dynamic>)['id'] == id);
    await prefs.setStringList(_p(_keyAppointments), list);
  }

  // ── Vitals ────────────────────────────────────────────────────────────────

  static Future<List<Vital>> getVitals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_p(_keyVitals)) ?? [];
    return raw.map((s) => Vital.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> saveVital(Vital vital) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyVitals)) ?? [];
    list.add(jsonEncode(vital.toJson()));
    await prefs.setStringList(_p(_keyVitals), list);
  }

  static Future<void> updateVital(Vital vital) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyVitals)) ?? [];
    final idx = list.indexWhere((s) =>
        (jsonDecode(s) as Map<String, dynamic>)['id'] == vital.id);
    if (idx != -1) {
      list[idx] = jsonEncode(vital.toJson());
      await prefs.setStringList(_p(_keyVitals), list);
    }
  }

  static Future<void> deleteVital(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyVitals)) ?? [];
    list.removeWhere(
        (s) => (jsonDecode(s) as Map<String, dynamic>)['id'] == id);
    await prefs.setStringList(_p(_keyVitals), list);
  }

  // ── Activities ────────────────────────────────────────────────────────────

  static Future<List<Activity>> getActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_p(_keyActivities)) ?? [];
    return raw.map((s) => Activity.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> saveActivity(Activity activity) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyActivities)) ?? [];
    list.add(jsonEncode(activity.toJson()));
    await prefs.setStringList(_p(_keyActivities), list);
  }

  static Future<void> updateActivity(Activity activity) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyActivities)) ?? [];
    final idx = list.indexWhere((s) =>
        (jsonDecode(s) as Map<String, dynamic>)['id'] == activity.id);
    if (idx != -1) {
      list[idx] = jsonEncode(activity.toJson());
      await prefs.setStringList(_p(_keyActivities), list);
    }
  }

  static Future<void> deleteActivity(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_p(_keyActivities)) ?? [];
    list.removeWhere(
        (s) => (jsonDecode(s) as Map<String, dynamic>)['id'] == id);
    await prefs.setStringList(_p(_keyActivities), list);
  }
}
