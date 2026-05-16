import 'package:flutter/material.dart';

class Medication {
  final String id;
  final String doctorName;
  final String prescriptionName;
  final String instructions;
  final int? notificationHour;
  final int? notificationMinute;

  Medication({
    required this.id,
    required this.doctorName,
    required this.prescriptionName,
    required this.instructions,
    this.notificationHour,
    this.notificationMinute,
  });

  TimeOfDay? get notificationTime {
    if (notificationHour == null || notificationMinute == null) return null;
    return TimeOfDay(hour: notificationHour!, minute: notificationMinute!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'doctorName': doctorName,
        'prescriptionName': prescriptionName,
        'instructions': instructions,
        'notificationHour': notificationHour,
        'notificationMinute': notificationMinute,
      };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'],
        doctorName: json['doctorName'],
        prescriptionName: json['prescriptionName'],
        instructions: json['instructions'],
        notificationHour: json['notificationHour'],
        notificationMinute: json['notificationMinute'],
      );
}
