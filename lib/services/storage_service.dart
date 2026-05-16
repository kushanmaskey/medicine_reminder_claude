import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prescription.dart';
import '../models/medication.dart';
import '../models/appointment.dart';
import '../models/vital.dart';

class StorageService {
  static const _keyPrescriptions = 'prescriptions';
  static const _keyMedications = 'medications';
  static const _keyAppointments = 'appointments';
  static const _keyVitals = 'vitals';

  static Future<List<Prescription>> getPrescriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyPrescriptions) ?? [];
    return raw.map((s) => Prescription.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> savePrescription(Prescription prescription) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyPrescriptions) ?? [];
    list.add(jsonEncode(prescription.toJson()));
    await prefs.setStringList(_keyPrescriptions, list);
  }

  static Future<void> deletePrescription(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyPrescriptions) ?? [];
    list.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == id;
    });
    await prefs.setStringList(_keyPrescriptions, list);
  }

  static Future<List<Medication>> getMedications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyMedications) ?? [];
    return raw.map((s) => Medication.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> saveMedication(Medication medication) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyMedications) ?? [];
    list.add(jsonEncode(medication.toJson()));
    await prefs.setStringList(_keyMedications, list);
  }

  static Future<void> deleteMedication(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyMedications) ?? [];
    list.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == id;
    });
    await prefs.setStringList(_keyMedications, list);
  }

  static Future<List<Appointment>> getAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyAppointments) ?? [];
    return raw.map((s) => Appointment.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> saveAppointment(Appointment appointment) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyAppointments) ?? [];
    list.add(jsonEncode(appointment.toJson()));
    await prefs.setStringList(_keyAppointments, list);
  }

  static Future<void> deleteAppointment(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyAppointments) ?? [];
    list.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == id;
    });
    await prefs.setStringList(_keyAppointments, list);
  }

  static Future<List<Vital>> getVitals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyVitals) ?? [];
    return raw.map((s) => Vital.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> saveVital(Vital vital) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyVitals) ?? [];
    list.add(jsonEncode(vital.toJson()));
    await prefs.setStringList(_keyVitals, list);
  }

  static Future<void> deleteVital(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyVitals) ?? [];
    list.removeWhere((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['id'] == id;
    });
    await prefs.setStringList(_keyVitals, list);
  }
}
