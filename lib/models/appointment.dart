import 'appointment_alert.dart';

class Appointment {
  final String id;
  final String title;
  final String doctorName;
  final String location;
  final String notes;
  final DateTime appointmentDateTime;
  final List<AppointmentAlert> alerts;

  Appointment({
    required this.id,
    required this.title,
    required this.doctorName,
    required this.location,
    required this.notes,
    required this.appointmentDateTime,
    this.alerts = const [],
  });

  List<AppointmentAlert> get activeAlerts =>
      alerts.where((a) => !a.acknowledged).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'doctorName': doctorName,
        'location': location,
        'notes': notes,
        'appointmentDateTime': appointmentDateTime.toIso8601String(),
        'alerts': alerts.map((a) => a.toJson()).toList(),
      };

  static DateTime _tryParse(dynamic value, DateTime fallback) {
    if (value == null) return fallback;
    try { return DateTime.parse(value as String); } catch (_) { return fallback; }
  }

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'],
        title: json['title'],
        doctorName: json['doctorName'],
        location: json['location'],
        notes: json['notes'],
        appointmentDateTime: _tryParse(json['appointmentDateTime'], DateTime.now()),
        alerts: (json['alerts'] as List<dynamic>? ?? [])
            .map((a) => AppointmentAlert.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}
