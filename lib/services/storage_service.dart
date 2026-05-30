import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/prescription.dart';
import '../models/prescription_alert.dart';
import '../models/medication.dart';
import '../models/appointment.dart';
import '../models/appointment_alert.dart';
import '../models/vital.dart';
import '../models/activity.dart';
import '../models/doctor.dart';
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

    final alertsByPrescriptionId = <String, List<PrescriptionAlert>>{};
    try {
      final alertRows = await _db
          .from('prescription_alerts')
          .select()
          .eq('user_id', _uid)
          .order('scheduled_at');
      for (final r in alertRows) {
        final prescriptionId = r['prescription_id'] as String;
        alertsByPrescriptionId.putIfAbsent(prescriptionId, () => []).add(
          PrescriptionAlert(
            id: r['id'],
            prescriptionId: prescriptionId,
            scheduledAt: _tryParseDate(r['scheduled_at']) ?? DateTime.now(),
            acknowledged: r['acknowledged'] as bool? ?? false,
          ),
        );
      }
    } catch (_) {
      // prescription_alerts table not yet created — alerts will be empty
    }

    return rows.map((r) {
      final prescriptionId = r['id'] as String;
      final p = Prescription.fromJson(_prescriptionFromRow(r));
      return Prescription(
        id: p.id,
        name: p.name,
        refillDate: p.refillDate,
        instructions: p.instructions,
        notificationHour: p.notificationHour,
        notificationMinute: p.notificationMinute,
        totalPills: p.totalPills,
        pillsPerDay: p.pillsPerDay,
        lastDecrementDate: p.lastDecrementDate,
        alerts: alertsByPrescriptionId[prescriptionId] ?? [],
      );
    }).toList();
  }

  static Future<void> savePrescription(Prescription p) async {
    await _db.from('prescriptions').insert({
      'id': p.id,
      'user_id': _uid,
      'name': p.name,
      'refill_date': p.refillDate?.toIso8601String(),
      'instructions': p.instructions,
      'notification_hour': p.notificationHour,
      'notification_minute': p.notificationMinute,
      'total_pills': p.totalPills,
      'pills_per_day': p.pillsPerDay,
      'last_decrement_date': p.lastDecrementDate?.toIso8601String(),
    });
  }

  static Future<void> updatePrescription(Prescription p) async {
    await _db.from('prescriptions').update({
      'name': p.name,
      'refill_date': p.refillDate?.toIso8601String(),
      'instructions': p.instructions,
      'notification_hour': p.notificationHour,
      'notification_minute': p.notificationMinute,
    }).eq('id', p.id).eq('user_id', _uid);
  }

  static Future<void> deletePrescription(String id) async {
    await _db.from('prescription_alerts').delete().eq('prescription_id', id).eq('user_id', _uid);
    await _db.from('prescriptions').delete().eq('id', id).eq('user_id', _uid);
  }

  // ── Prescription Alerts ───────────────────────────────────────────────────

  static Future<void> savePrescriptionAlert(PrescriptionAlert alert) async {
    try {
      await _db.from('prescription_alerts').insert({
        'id': alert.id,
        'prescription_id': alert.prescriptionId,
        'user_id': _uid,
        'scheduled_at': alert.scheduledAt.toIso8601String(),
        'acknowledged': false,
      });
    } catch (_) {}
  }

  static Future<void> deletePrescriptionAlert(String alertId) async {
    try {
      await _db.from('prescription_alerts').delete().eq('id', alertId).eq('user_id', _uid);
    } catch (_) {}
  }

  static Future<void> acknowledgePrescriptionAlert(String alertId) async {
    try {
      await _db.from('prescription_alerts')
          .update({'acknowledged': true})
          .eq('id', alertId)
          .eq('user_id', _uid);
    } catch (_) {}
  }

  static Future<void> decrementPillsIfNeeded() async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final rows = await _db
        .from('prescriptions')
        .select('id, total_pills, pills_per_day, last_decrement_date')
        .eq('user_id', _uid)
        .not('pills_per_day', 'is', null)
        .not('total_pills', 'is', null);

    for (final row in rows) {
      final lastRaw = row['last_decrement_date'] as String?;
      final lastDate = lastRaw != null ? _tryParseDate(lastRaw) : null;
      final lastDay = lastDate != null
          ? DateTime(lastDate.year, lastDate.month, lastDate.day)
          : null;

      if (lastDay == null || lastDay.isBefore(todayDate)) {
        final current = (row['total_pills'] as int?) ?? 0;
        final perDay = (row['pills_per_day'] as int?) ?? 0;
        final newTotal = (current - perDay).clamp(0, current);
        await _db.from('prescriptions').update({
          'total_pills': newTotal,
          'last_decrement_date': todayDate.toIso8601String(),
        }).eq('id', row['id']).eq('user_id', _uid);
      }
    }
  }

  static DateTime? _tryParseDate(String? s) {
    if (s == null) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  static Map<String, dynamic> _prescriptionFromRow(Map<String, dynamic> r) => {
    'id': r['id'],
    'name': r['name'],
    'refillDate': r['refill_date'],
    'instructions': r['instructions'] ?? '',
    'notificationHour': r['notification_hour'],
    'notificationMinute': r['notification_minute'],
    'totalPills': r['total_pills'],
    'pillsPerDay': r['pills_per_day'],
    'lastDecrementDate': r['last_decrement_date'],
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

    List<dynamic> alertRows = [];
    try {
      alertRows = await _db
          .from('appointment_alerts')
          .select()
          .eq('user_id', _uid)
          .order('scheduled_at');
    } catch (_) {}

    final alertsByApptId = <String, List<AppointmentAlert>>{};
    for (final r in alertRows) {
      final apptId = r['appointment_id'] as String;
      alertsByApptId.putIfAbsent(apptId, () => []).add(AppointmentAlert(
        id: r['id'],
        appointmentId: apptId,
        scheduledAt: DateTime.parse(r['scheduled_at']).toLocal(),
        acknowledged: r['acknowledged'] as bool? ?? false,
      ));
    }

    return rows.map((r) {
      final apptId = r['id'] as String;
      return Appointment(
        id: apptId,
        title: r['title'],
        doctorName: r['doctor_name'] ?? '',
        location: r['location'] ?? '',
        notes: r['notes'] ?? '',
        appointmentDateTime: DateTime.parse(r['appointment_date_time']).toLocal(),
        alerts: alertsByApptId[apptId] ?? [],
      );
    }).toList();
  }

  static Future<void> saveAppointment(Appointment a) async {
    await _db.from('appointments').insert({
      'id': a.id,
      'user_id': _uid,
      'title': a.title,
      'doctor_name': a.doctorName,
      'location': a.location,
      'notes': a.notes,
      'appointment_date_time': a.appointmentDateTime.toUtc().toIso8601String(),
    });
  }

  static Future<void> updateAppointment(Appointment a) async {
    await _db.from('appointments').update({
      'title': a.title,
      'doctor_name': a.doctorName,
      'location': a.location,
      'notes': a.notes,
      'appointment_date_time': a.appointmentDateTime.toUtc().toIso8601String(),
    }).eq('id', a.id).eq('user_id', _uid);
  }

  static Future<void> deleteAppointment(String id) async {
    await _db.from('appointment_alerts').delete().eq('appointment_id', id).eq('user_id', _uid);
    await _db.from('appointments').delete().eq('id', id).eq('user_id', _uid);
  }

  // ── Appointment Alerts ────────────────────────────────────────────────────

  static Future<void> saveAlert(AppointmentAlert alert) async {
    await _db.from('appointment_alerts').insert({
      'id': alert.id,
      'appointment_id': alert.appointmentId,
      'user_id': _uid,
      'scheduled_at': alert.scheduledAt.toUtc().toIso8601String(),
      'acknowledged': false,
    });
  }

  static Future<void> deleteAlert(String alertId) async {
    await _db.from('appointment_alerts').delete().eq('id', alertId).eq('user_id', _uid);
  }

  static Future<void> acknowledgeAlert(String alertId) async {
    await _db.from('appointment_alerts')
        .update({'acknowledged': true})
        .eq('id', alertId)
        .eq('user_id', _uid);
  }

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
      'category': v.category,
      'event_name': v.eventName,
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
      'category': v.category,
      'event_name': v.eventName,
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
    'category': r['category'] ?? 'daily',
    'eventName': r['event_name'] ?? '',
    'bpSystolic': r['bp_systolic'],
    'bpDiastolic': r['bp_diastolic'],
    'weight': r['weight'],
    'weightUnit': r['weight_unit'] ?? 'lbs',
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

  // ── Doctors ───────────────────────────────────────────────────────────────

  static Future<List<Doctor>> getDoctors() async {
    final rows = await _db
        .from('doctors')
        .select()
        .eq('user_id', _uid)
        .order('last_name');
    return rows.map((r) => Doctor.fromJson({
      'id': r['id'],
      'firstName': r['first_name'] ?? '',
      'lastName': r['last_name'] ?? '',
      'credential': r['credential'] ?? '',
      'specialty': r['specialty'] ?? '',
      'phone': r['phone'] ?? '',
      'address': r['address'] ?? '',
      'city': r['city'] ?? '',
      'state': r['state'] ?? '',
      'zip': r['zip'] ?? '',
      'npiNumber': r['npi_number'] ?? '',
      'notes': r['notes'] ?? '',
    })).toList();
  }

  static Future<void> saveDoctor(Doctor d) async {
    await _db.from('doctors').insert({
      'id': d.id,
      'user_id': _uid,
      'first_name': d.firstName,
      'last_name': d.lastName,
      'credential': d.credential,
      'specialty': d.specialty,
      'phone': d.phone,
      'address': d.address,
      'city': d.city,
      'state': d.state,
      'zip': d.zip,
      'npi_number': d.npiNumber,
      'notes': d.notes,
    });
  }

  static Future<void> updateDoctor(Doctor d) async {
    await _db.from('doctors').update({
      'first_name': d.firstName,
      'last_name': d.lastName,
      'credential': d.credential,
      'specialty': d.specialty,
      'phone': d.phone,
      'address': d.address,
      'city': d.city,
      'state': d.state,
      'zip': d.zip,
      'npi_number': d.npiNumber,
      'notes': d.notes,
    }).eq('id', d.id).eq('user_id', _uid);
  }

  static Future<void> deleteDoctor(String id) async {
    await _db.from('doctors').delete().eq('id', id).eq('user_id', _uid);
  }
}
