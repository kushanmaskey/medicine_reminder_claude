import 'package:flutter/material.dart';

class Prescription {
  final String id;
  final String name;
  final DateTime? refillDate;
  final String instructions;
  final int? notificationHour;
  final int? notificationMinute;
  final int? totalPills;
  final int? pillsPerDay;
  final DateTime? lastDecrementDate;

  Prescription({
    required this.id,
    required this.name,
    this.refillDate,
    required this.instructions,
    this.notificationHour,
    this.notificationMinute,
    this.totalPills,
    this.pillsPerDay,
    this.lastDecrementDate,
  });

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
        'refillDate': refillDate?.toIso8601String(),
        'instructions': instructions,
        'notificationHour': notificationHour,
        'notificationMinute': notificationMinute,
        'totalPills': totalPills,
        'pillsPerDay': pillsPerDay,
        'lastDecrementDate': lastDecrementDate?.toIso8601String(),
      };

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
        id: json['id'],
        name: json['name'],
        refillDate: json['refillDate'] != null
            ? DateTime.parse(json['refillDate'])
            : null,
        instructions: json['instructions'],
        notificationHour: json['notificationHour'],
        notificationMinute: json['notificationMinute'],
        totalPills: json['totalPills'],
        pillsPerDay: json['pillsPerDay'],
        lastDecrementDate: json['lastDecrementDate'] != null
            ? DateTime.parse(json['lastDecrementDate'])
            : null,
      );
}
