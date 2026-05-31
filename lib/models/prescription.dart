import 'package:flutter/material.dart';
import 'prescription_alert.dart';

class Prescription {
  final String id;
  final String name;
  final String type; // 'prescribed' | 'otc'
  final String? doctorId;
  final DateTime? refillDate;
  final String instructions;
  final int? notificationHour;
  final int? notificationMinute;
  final int? totalPills;
  final int? pillsPerDay;
  final DateTime? lastDecrementDate;
  final List<PrescriptionAlert> alerts;

  Prescription({
    required this.id,
    required this.name,
    this.type = 'prescribed',
    this.doctorId,
    this.refillDate,
    required this.instructions,
    this.notificationHour,
    this.notificationMinute,
    this.totalPills,
    this.pillsPerDay,
    this.lastDecrementDate,
    this.alerts = const [],
  });

  bool get isOtc => type == 'otc';

  TimeOfDay? get notificationTime {
    if (notificationHour == null || notificationMinute == null) return null;
    return TimeOfDay(hour: notificationHour!, minute: notificationMinute!);
  }

  bool get hasLowSupply {
    if (totalPills == null || pillsPerDay == null || pillsPerDay! <= 0) return false;
    return totalPills! <= pillsPerDay! * 7;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'doctorId': doctorId,
        'refillDate': refillDate?.toIso8601String(),
        'instructions': instructions,
        'notificationHour': notificationHour,
        'notificationMinute': notificationMinute,
        'totalPills': totalPills,
        'pillsPerDay': pillsPerDay,
        'lastDecrementDate': lastDecrementDate?.toIso8601String(),
      };

  static DateTime? _tryParse(dynamic value) {
    if (value == null) return null;
    try { return DateTime.parse(value as String); } catch (_) { return null; }
  }

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
        id: json['id'],
        name: json['name'],
        type: json['type'] as String? ?? 'prescribed',
        doctorId: json['doctorId'] as String?,
        refillDate: _tryParse(json['refillDate']),
        instructions: json['instructions'],
        notificationHour: json['notificationHour'],
        notificationMinute: json['notificationMinute'],
        totalPills: json['totalPills'],
        pillsPerDay: json['pillsPerDay'],
        lastDecrementDate: _tryParse(json['lastDecrementDate']),
      );
}
