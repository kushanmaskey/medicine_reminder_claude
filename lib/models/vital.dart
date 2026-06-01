class Vital {
  final String id;
  final DateTime recordedAt;
  final String category; // 'daily' | 'monthly' | 'open'
  final String eventName; // used by 'open' category
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
    this.category = 'daily',
    this.eventName = '',
    this.bpSystolic,
    this.bpDiastolic,
    this.weight,
    this.weightUnit = 'lbs',
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
        'category': category,
        'eventName': eventName,
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

  static DateTime? _tryParse(dynamic value) {
    if (value == null) return null;
    try { return DateTime.parse(value as String).toLocal(); } catch (_) { return null; }
  }

  factory Vital.fromJson(Map<String, dynamic> json) => Vital(
        id: json['id'],
        recordedAt: _tryParse(json['recordedAt']) ?? DateTime.now(),
        category: json['category'] ?? 'daily',
        eventName: json['eventName'] ?? '',
        bpSystolic: json['bpSystolic'],
        bpDiastolic: json['bpDiastolic'],
        weight: (json['weight'] as num?)?.toDouble(),
        weightUnit: json['weightUnit'] ?? 'lbs',
        sugarLevel: (json['sugarLevel'] as num?)?.toDouble(),
        sugarUnit: json['sugarUnit'] ?? 'mg/dL',
        cholesterol: (json['cholesterol'] as num?)?.toDouble(),
        cholesterolUnit: json['cholesterolUnit'] ?? 'mg/dL',
        colonoscopyDate: _tryParse(json['colonoscopyDate']),
        periodDate: _tryParse(json['periodDate']),
        mammogramDate: _tryParse(json['mammogramDate']),
        riskLevel: json['riskLevel'] ?? 'Low',
        notes: json['notes'] ?? '',
      );
}
