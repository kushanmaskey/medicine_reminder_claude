class Vital {
  final String id;
  final DateTime recordedAt;
  final int? bpSystolic;
  final int? bpDiastolic;
  final double? weight;
  final String weightUnit;
  final double? sugarLevel;
  final String sugarUnit;
  final double? cholesterol;
  final String cholesterolUnit;
  final DateTime? colonoscopyDate;
  final DateTime? periodDate;
  final DateTime? mammogramDate;
  final String riskLevel;
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
    this.cholesterol,
    this.cholesterolUnit = 'mg/dL',
    this.colonoscopyDate,
    this.periodDate,
    this.mammogramDate,
    required this.riskLevel,
    this.notes = '',
  });

  bool get hasBP => bpSystolic != null && bpDiastolic != null;
  String get bpDisplay => hasBP ? '$bpSystolic/$bpDiastolic mmHg' : '—';
  String get weightDisplay =>
      weight != null ? '${weight!.toStringAsFixed(1)} $weightUnit' : '—';
  String get sugarDisplay =>
      sugarLevel != null ? '${sugarLevel!.toStringAsFixed(1)} $sugarUnit' : '—';
  String get cholesterolDisplay =>
      cholesterol != null ? '${cholesterol!.toStringAsFixed(1)} $cholesterolUnit' : '—';

  static String _fmtDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String get colonoscopyDisplay =>
      colonoscopyDate != null ? _fmtDate(colonoscopyDate!) : '—';
  String get periodDisplay =>
      periodDate != null ? _fmtDate(periodDate!) : '—';
  String get mammogramDisplay =>
      mammogramDate != null ? _fmtDate(mammogramDate!) : '—';

  Map<String, dynamic> toJson() => {
        'id': id,
        'recordedAt': recordedAt.toIso8601String(),
        'bpSystolic': bpSystolic,
        'bpDiastolic': bpDiastolic,
        'weight': weight,
        'weightUnit': weightUnit,
        'sugarLevel': sugarLevel,
        'sugarUnit': sugarUnit,
        'cholesterol': cholesterol,
        'cholesterolUnit': cholesterolUnit,
        'colonoscopyDate': colonoscopyDate?.toIso8601String(),
        'periodDate': periodDate?.toIso8601String(),
        'mammogramDate': mammogramDate?.toIso8601String(),
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
        cholesterol: (json['cholesterol'] as num?)?.toDouble(),
        cholesterolUnit: json['cholesterolUnit'] ?? 'mg/dL',
        colonoscopyDate: json['colonoscopyDate'] != null
            ? DateTime.parse(json['colonoscopyDate'])
            : null,
        periodDate: json['periodDate'] != null
            ? DateTime.parse(json['periodDate'])
            : null,
        mammogramDate: json['mammogramDate'] != null
            ? DateTime.parse(json['mammogramDate'])
            : null,
        riskLevel: json['riskLevel'] ?? 'Low',
        notes: json['notes'] ?? '',
      );
}
