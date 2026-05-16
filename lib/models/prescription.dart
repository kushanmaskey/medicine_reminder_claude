import 'package:flutter/material.dart';

class Prescription {
  final String id;
  final String name;
  final DateTime refillDate;
  final String instructions;
  final int? notificationHour;
  final int? notificationMinute;

  Prescription({
    required this.id,
    required this.name,
    required this.refillDate,
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
        'name': name,
        'refillDate': refillDate.toIso8601String(),
        'instructions': instructions,
        'notificationHour': notificationHour,
        'notificationMinute': notificationMinute,
      };

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
        id: json['id'],
        name: json['name'],
        refillDate: DateTime.parse(json['refillDate']),
        instructions: json['instructions'],
        notificationHour: json['notificationHour'],
        notificationMinute: json['notificationMinute'],
      );
}
