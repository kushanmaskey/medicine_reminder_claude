class BpReading {
  final String id;
  final int systolic;
  final int diastolic;
  final DateTime time;
  final String notes;

  BpReading({
    required this.id,
    required this.systolic,
    required this.diastolic,
    required this.time,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'systolic': systolic,
        'diastolic': diastolic,
        'time': time.toUtc().toIso8601String(),
        if (notes.isNotEmpty) 'notes': notes,
      };

  factory BpReading.fromJson(Map<String, dynamic> json) => BpReading(
        id: json['id'] as String,
        systolic: json['systolic'] as int,
        diastolic: json['diastolic'] as int,
        time: DateTime.parse(json['time'] as String).toLocal(),
        notes: json['notes'] as String? ?? '',
      );
}

class VitalReading {
  final String id;
  final double value;
  final DateTime time;
  final String notes;

  VitalReading({
    required this.id,
    required this.value,
    required this.time,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'value': value,
        'time': time.toUtc().toIso8601String(),
        if (notes.isNotEmpty) 'notes': notes,
      };

  factory VitalReading.fromJson(Map<String, dynamic> json) => VitalReading(
        id: json['id'] as String,
        value: (json['value'] as num).toDouble(),
        time: DateTime.parse(json['time'] as String).toLocal(),
        notes: json['notes'] as String? ?? '',
      );
}
