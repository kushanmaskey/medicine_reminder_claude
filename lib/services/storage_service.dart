import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prescription.dart';
import '../models/medication.dart';
import '../models/appointment.dart';
import '../models/vital.dart';
import '../models/activity.dart';
import 'auth_service.dart';

class StorageService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => AuthService.currentUserId!;

  // ── Prescriptions ─────────────────────────────────────────────────────────

  static Future<List<Prescription>> getPrescriptions() async {
    final rows = await _db
        .from('prescriptions')
        .select()
        .eq('user_id', _uid)
        .order('created_at');
    return rows.map((r) => Prescription.fromJson(_prescriptionFromRow(r))).toList();
  }

  static Future<void> savePrescription(Prescription p) async {
    await _db.from('prescriptions').insert({
      'id': p.id,
      'user_id': _uid,
      'name': p.name,
      'refill_date': p.refillDate.toIso8601String(),
      'instructions': p.instructions,
      'notification_hour': p.notificationHour,
      'notification_minute': p.notificationMinute,
    });
  }

  static Future<void> updatePrescription(Prescription p) async {
    await _db.from('prescriptions').update({
      'name': p.name,
      'refill_date': p.refillDate.toIso8601String(),
      'instructions': p.instructions,
      'notification_hour': p.notificationHour,
      'notification_minute': p.notificationMinute,
    }).eq('id', p.id).eq('user_id', _uid);
  }

  static Future<void> deletePrescription(String id) async {
    await _db.from('prescriptions').delete().eq('id', id).eq('user_id', _uid);
  }

  static Map<String, dynamic> _prescriptionFromRow(Map<String, dynamic> r) => {
    'id': r['id'],
    'name': r['name'],
    'refillDate': r['refill_date'],
    'instructions': r['instructions'] ?? '',
    'notificationHour': r['notification_hour'],
    'notificationMinute': r['notification_minute'],
  };

  // ── Medications ───────────────────────────────────────────────────────────

  static Future<List<Medication>> getMedications() async {
    final rows = await _db
        .from('medications')
        .select()
        .eq('user_id', _uid)
        .order('created_at');
    return rows.map((r) => Medication.fromJson(_medicationFromRow(r))).toList();
  }

  static Future<void> saveMedication(Medication m) async {
    await _db.from('medications').insert({
      'id': m.id,
      'user_id': _uid,
      'doctor_name': m.doctorName,
      'prescription_name': m.prescriptionName,
      'instructions': m.instructions,
      'notification_hour': m.notificationHour,
      'notification_minute': m.notificationMinute,
    });
  }

  static Future<void> deleteMedication(String id) async {
    await _db.from('medications').delete().eq('id', id).eq('user_id', _uid);
  }

  static Map<String, dynamic> _medicationFromRow(Map<String, dynamic> r) => {
    'id': r['id'],
    'doctorName': r['doctor_name'] ?? '',
    'prescriptionName': r['prescription_name'],
    'instructions': r['instructions'] ?? '',
    'notificationHour': r['notification_hour'],
    'notificationMinute': r['notification_minute'],
  };

  // ── Appointments ──────────────────────────────────────────────────────────

  static Future<List<Appointment>> getAppointments() async {
    final rows = await _db
        .from('appointments')
        .select()
        .eq('user_id', _uid)
        .order('appointment_date_time');
    return rows.map((r) => Appointment.fromJson(_appointmentFromRow(r))).toList();
  }

  static Future<void> saveAppointment(Appointment a) async {
    await _db.from('appointments').insert({
      'id': a.id,
      'user_id': _uid,
      'title': a.title,
      'doctor_name': a.doctorName,
      'location': a.location,
      'notes': a.notes,
      'appointment_date_time': a.appointmentDateTime.toIso8601String(),
    });
  }

  static Future<void> updateAppointment(Appointment a) async {
    await _db.from('appointments').update({
      'title': a.title,
      'doctor_name': a.doctorName,
      'location': a.location,
      'notes': a.notes,
      'appointment_date_time': a.appointmentDateTime.toIso8601String(),
    }).eq('id', a.id).eq('user_id', _uid);
  }

  static Future<void> deleteAppointment(String id) async {
    await _db.from('appointments').delete().eq('id', id).eq('user_id', _uid);
  }

  static Map<String, dynamic> _appointmentFromRow(Map<String, dynamic> r) => {
    'id': r['id'],
    'title': r['title'],
    'doctorName': r['doctor_name'] ?? '',
    'location': r['location'] ?? '',
    'notes': r['notes'] ?? '',
    'appointmentDateTime': r['appointment_date_time'],
  };

  // ── Vitals ────────────────────────────────────────────────────────────────

  static Future<List<Vital>> getVitals() async {
    final rows = await _db
        .from('vitals')
        .select()
        .eq('user_id', _uid)
        .order('recorded_at', ascending: false);
    return rows.map((r) => Vital.fromJson(_vitalFromRow(r))).toList();
  }

  static Future<void> saveVital(Vital v) async {
    await _db.from('vitals').insert({
      'id': v.id,
      'user_id': _uid,
      'recorded_at': v.recordedAt.toIso8601String(),
      'bp_systolic': v.bpSystolic,
      'bp_diastolic': v.bpDiastolic,
      'weight': v.weight,
      'weight_unit': v.weightUnit,
      'sugar_level': v.sugarLevel,
      'sugar_unit': v.sugarUnit,
      'cholesterol': v.cholesterol,
      'cholesterol_unit': v.cholesterolUnit,
      'colonoscopy_date': v.colonoscopyDate?.toIso8601String(),
      'period_date': v.periodDate?.toIso8601String(),
      'mammogram_date': v.mammogramDate?.toIso8601String(),
      'risk_level': v.riskLevel,
      'notes': v.notes,
    });
  }

  static Future<void> updateVital(Vital v) async {
    await _db.from('vitals').update({
      'recorded_at': v.recordedAt.toIso8601String(),
      'bp_systolic': v.bpSystolic,
      'bp_diastolic': v.bpDiastolic,
      'weight': v.weight,
      'weight_unit': v.weightUnit,
      'sugar_level': v.sugarLevel,
      'sugar_unit': v.sugarUnit,
      'cholesterol': v.cholesterol,
      'cholesterol_unit': v.cholesterolUnit,
      'colonoscopy_date': v.colonoscopyDate?.toIso8601String(),
      'period_date': v.periodDate?.toIso8601String(),
      'mammogram_date': v.mammogramDate?.toIso8601String(),
      'risk_level': v.riskLevel,
      'notes': v.notes,
    }).eq('id', v.id).eq('user_id', _uid);
  }

  static Future<void> deleteVital(String id) async {
    await _db.from('vitals').delete().eq('id', id).eq('user_id', _uid);
  }

  static Map<String, dynamic> _vitalFromRow(Map<String, dynamic> r) => {
    'id': r['id'],
    'recordedAt': r['recorded_at'],
    'bpSystolic': r['bp_systolic'],
    'bpDiastolic': r['bp_diastolic'],
    'weight': r['weight'],
    'weightUnit': r['weight_unit'] ?? 'kg',
    'sugarLevel': r['sugar_level'],
    'sugarUnit': r['sugar_unit'] ?? 'mg/dL',
    'cholesterol': r['cholesterol'],
    'cholesterolUnit': r['cholesterol_unit'] ?? 'mg/dL',
    'colonoscopyDate': r['colonoscopy_date'],
    'periodDate': r['period_date'],
    'mammogramDate': r['mammogram_date'],
    'riskLevel': r['risk_level'] ?? 'Low',
    'notes': r['notes'] ?? '',
  };

  // ── Activities ────────────────────────────────────────────────────────────

  static Future<List<Activity>> getActivities() async {
    final rows = await _db
        .from('activities')
        .select()
        .eq('user_id', _uid)
        .order('recorded_at', ascending: false);
    return rows.map((r) => Activity.fromJson(_activityFromRow(r))).toList();
  }

  static Future<void> saveActivity(Activity a) async {
    await _db.from('activities').insert({
      'id': a.id,
      'user_id': _uid,
      'type': a.type,
      'walk_type': a.walkType,
      'distance': a.distance,
      'duration': a.duration,
      'recorded_at': a.recordedAt.toIso8601String(),
      'notes': a.notes,
    });
  }

  static Future<void> updateActivity(Activity a) async {
    await _db.from('activities').update({
      'type': a.type,
      'walk_type': a.walkType,
      'distance': a.distance,
      'duration': a.duration,
      'recorded_at': a.recordedAt.toIso8601String(),
      'notes': a.notes,
    }).eq('id', a.id).eq('user_id', _uid);
  }

  static Future<void> deleteActivity(String id) async {
    await _db.from('activities').delete().eq('id', id).eq('user_id', _uid);
  }

  static Map<String, dynamic> _activityFromRow(Map<String, dynamic> r) => {
    'id': r['id'],
    'type': r['type'],
    'walkType': r['walk_type'] ?? 'Regular',
    'distance': r['distance'],
    'duration': r['duration'],
    'recordedAt': r['recorded_at'],
    'notes': r['notes'] ?? '',
  };
}
