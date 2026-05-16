import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prescription.dart';
import '../models/medication.dart';

class StorageService {
  static const _keyPrescriptions = 'prescriptions';
  static const _keyMedications = 'medications';

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
}
