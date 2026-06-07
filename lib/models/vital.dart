import 'vital_reading.dart';

class Vital {
  final String id;
  final DateTime recordedAt;
  final String category; // 'daily' | 'monthly' | 'open'
  final String eventName;

  // Daily — multiple readings per type
  final List<BpReading> bpReadings;
  final List<VitalReading> sugarReadings;
  final List<VitalReading> cholesterolReadings;
  final List<VitalReading> weightReadings;

  // Units (section-level)
  final String weightUnit;
  final String sugarUnit;
  final String cholesterolUnit;

  // Misc fields
  final DateTime? colonoscopyDate;
  final String colonoscopyLocation;
  final String colonoscopyNotes;
  final DateTime? periodDate;
  final String periodNotes;
  final DateTime? mammogramDate;
  final String mammogramLocation;
  final String mammogramNotes;
  final DateTime? dentalDate;
  final String dentalLocation;
  final String dentalNotes;
  final DateTime? eyeExamDate;
  final String eyeExamLocation;
  final String eyeExamNotes;

  final String riskLevel;
  final String notes;
  final String? doctorId;
  final String location;

  Vital({
    required this.id,
    required this.recordedAt,
    this.category = 'daily',
    this.eventName = '',
    this.bpReadings = const [],
    this.sugarReadings = const [],
    this.cholesterolReadings = const [],
    this.weightReadings = const [],
    this.weightUnit = 'lbs',
    this.sugarUnit = 'mg/dL',
    this.cholesterolUnit = 'mg/dL',
    this.colonoscopyDate,
    this.colonoscopyLocation = '',
    this.colonoscopyNotes = '',
    this.periodDate,
    this.periodNotes = '',
    this.mammogramDate,
    this.mammogramLocation = '',
    this.mammogramNotes = '',
    this.dentalDate,
    this.dentalLocation = '',
    this.dentalNotes = '',
    this.eyeExamDate,
    this.eyeExamLocation = '',
    this.eyeExamNotes = '',
    required this.riskLevel,
    this.notes = '',
    this.doctorId,
    this.location = '',
  });

  // Display getters — use latest reading
  bool get hasBP => bpReadings.isNotEmpty;
  String get bpDisplay => hasBP
      ? '${bpReadings.last.systolic}/${bpReadings.last.diastolic} mmHg'
      : '—';

  bool get hasWeight => weightReadings.isNotEmpty;
  String get weightDisplay => hasWeight
      ? '${weightReadings.last.value.toStringAsFixed(1)} $weightUnit'
      : '—';

  bool get hasSugar => sugarReadings.isNotEmpty;
  String get sugarDisplay => hasSugar
      ? '${sugarReadings.last.value.toStringAsFixed(1)} $sugarUnit'
      : '—';

  bool get hasCholesterol => cholesterolReadings.isNotEmpty;
  String get cholesterolDisplay => hasCholesterol
      ? '${cholesterolReadings.last.value.toStringAsFixed(1)} $cholesterolUnit'
      : '—';

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
        'bpReadings': bpReadings.map((r) => r.toJson()).toList(),
        'sugarReadings': sugarReadings.map((r) => r.toJson()).toList(),
        'cholesterolReadings': cholesterolReadings.map((r) => r.toJson()).toList(),
        'weightReadings': weightReadings.map((r) => r.toJson()).toList(),
        'weightUnit': weightUnit,
        'sugarUnit': sugarUnit,
        'cholesterolUnit': cholesterolUnit,
        'colonoscopyDate': colonoscopyDate?.toIso8601String(),
        if (colonoscopyLocation.isNotEmpty) 'colonoscopyLocation': colonoscopyLocation,
        if (colonoscopyNotes.isNotEmpty) 'colonoscopyNotes': colonoscopyNotes,
        'periodDate': periodDate?.toIso8601String(),
        if (periodNotes.isNotEmpty) 'periodNotes': periodNotes,
        'mammogramDate': mammogramDate?.toIso8601String(),
        if (mammogramLocation.isNotEmpty) 'mammogramLocation': mammogramLocation,
        if (mammogramNotes.isNotEmpty) 'mammogramNotes': mammogramNotes,
        'dentalDate': dentalDate?.toIso8601String(),
        if (dentalLocation.isNotEmpty) 'dentalLocation': dentalLocation,
        if (dentalNotes.isNotEmpty) 'dentalNotes': dentalNotes,
        'eyeExamDate': eyeExamDate?.toIso8601String(),
        if (eyeExamLocation.isNotEmpty) 'eyeExamLocation': eyeExamLocation,
        if (eyeExamNotes.isNotEmpty) 'eyeExamNotes': eyeExamNotes,
        'riskLevel': riskLevel,
        'notes': notes,
        'doctorId': doctorId,
        if (location.isNotEmpty) 'location': location,
      };

  static DateTime? _tryParse(dynamic value) {
    if (value == null) return null;
    try { return DateTime.parse(value as String).toLocal(); } catch (_) { return null; }
  }

  factory Vital.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final recordedAt = _tryParse(json['recordedAt']) ?? DateTime.now();

    // Migrate old single-value BP → list
    List<BpReading> bpReadings = [];
    if (json['bpReadings'] != null) {
      bpReadings = (json['bpReadings'] as List)
          .map((e) => BpReading.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['bpSystolic'] != null && json['bpDiastolic'] != null) {
      bpReadings = [
        BpReading(
          id: '${id}_bp_0',
          systolic: json['bpSystolic'] as int,
          diastolic: json['bpDiastolic'] as int,
          time: recordedAt,
        )
      ];
    }

    // Migrate old single-value sugar → list
    List<VitalReading> sugarReadings = [];
    if (json['sugarReadings'] != null) {
      sugarReadings = (json['sugarReadings'] as List)
          .map((e) => VitalReading.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['sugarLevel'] != null) {
      sugarReadings = [
        VitalReading(
          id: '${id}_sugar_0',
          value: (json['sugarLevel'] as num).toDouble(),
          time: recordedAt,
        )
      ];
    }

    // Migrate old single-value cholesterol → list
    List<VitalReading> cholesterolReadings = [];
    if (json['cholesterolReadings'] != null) {
      cholesterolReadings = (json['cholesterolReadings'] as List)
          .map((e) => VitalReading.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['cholesterol'] != null) {
      cholesterolReadings = [
        VitalReading(
          id: '${id}_chol_0',
          value: (json['cholesterol'] as num).toDouble(),
          time: recordedAt,
        )
      ];
    }

    // Migrate old single-value weight → list
    List<VitalReading> weightReadings = [];
    if (json['weightReadings'] != null) {
      weightReadings = (json['weightReadings'] as List)
          .map((e) => VitalReading.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['weight'] != null) {
      weightReadings = [
        VitalReading(
          id: '${id}_weight_0',
          value: (json['weight'] as num).toDouble(),
          time: recordedAt,
        )
      ];
    }

    return Vital(
      id: id,
      recordedAt: recordedAt,
      category: json['category'] ?? 'daily',
      eventName: json['eventName'] ?? '',
      bpReadings: bpReadings,
      sugarReadings: sugarReadings,
      cholesterolReadings: cholesterolReadings,
      weightReadings: weightReadings,
      weightUnit: json['weightUnit'] ?? 'lbs',
      sugarUnit: json['sugarUnit'] ?? 'mg/dL',
      cholesterolUnit: json['cholesterolUnit'] ?? 'mg/dL',
      colonoscopyDate: _tryParse(json['colonoscopyDate']),
      colonoscopyLocation: json['colonoscopyLocation'] ?? '',
      colonoscopyNotes: json['colonoscopyNotes'] ?? '',
      periodDate: _tryParse(json['periodDate']),
      periodNotes: json['periodNotes'] ?? '',
      mammogramDate: _tryParse(json['mammogramDate']),
      mammogramLocation: json['mammogramLocation'] ?? '',
      mammogramNotes: json['mammogramNotes'] ?? '',
      dentalDate: _tryParse(json['dentalDate']),
      dentalLocation: json['dentalLocation'] ?? '',
      dentalNotes: json['dentalNotes'] ?? '',
      eyeExamDate: _tryParse(json['eyeExamDate']),
      eyeExamLocation: json['eyeExamLocation'] ?? '',
      eyeExamNotes: json['eyeExamNotes'] ?? '',
      riskLevel: json['riskLevel'] ?? 'Low',
      notes: json['notes'] ?? '',
      doctorId: json['doctorId'] as String?,
      location: json['location'] ?? '',
    );
  }
}
