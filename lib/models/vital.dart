class Vital {
  final String id;
  final DateTime recordedAt;
  final int? bpSystolic;
  final int? bpDiastolic;
  final double? weight;
  final String weightUnit; // 'kg' or 'lbs'
  final double? sugarLevel;
  final String sugarUnit; // 'mg/dL' or 'mmol/L'
  final String riskLevel; // 'Low', 'Medium', 'High'
  final String notes;

  Vital({
    required this.id,
    required this.recordedAt,
    this.bpSystolic,
    this.bpDiastolic,
    this.weight,
    this.weightUnit = 'kg',
    this.sugarLevel,
    this.sugarUnit = 'mg/dL',
    required this.riskLevel,
    this.notes = '',
  });

  bool get hasBP => bpSystolic != null && bpDiastolic != null;
  String get bpDisplay => hasBP ? '$bpSystolic/$bpDiastolic mmHg' : '—';
  String get weightDisplay =>
      weight != null ? '${weight!.toStringAsFixed(1)} $weightUnit' : '—';
  String get sugarDisplay =>
      sugarLevel != null ? '${sugarLevel!.toStringAsFixed(1)} $sugarUnit' : '—';

  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': recordedAt.toIso8601String(),
        'bpSystolic': bpSystolic,
        'bpDiastolic': bpDiastolic,
        'weight': weight,
        'weightUnit': weightUnit,
        'sugarLevel': sugarLevel,
        'sugarUnit': sugarUnit,
        'riskLevel': riskLevel,
        'notes': notes,
      };

  factory Vital.fromJson(Map<String, dynamic> json) => Vital(
        id: json['id'],
        recordedAt: DateTime.parse(json['recordedAt']),
        bpSystolic: json['bpSystolic'],
        bpDiastolic: json['bpDiastolic'],
        weight: (json['weight'] as num?)?.toDouble(),
        weightUnit: json['weightUnit'] ?? 'kg',
        sugarLevel: (json['sugarLevel'] as num?)?.toDouble(),
        sugarUnit: json['sugarUnit'] ?? 'mg/dL',
        riskLevel: json['riskLevel'] ?? 'Low',
        notes: json['notes'] ?? '',
      );
}
