import 'dart:convert';
import 'vital_reading.dart';

class Vital {
  final String id;
  final DateTime recordedAt;
  final String category; // 'daily' | 'monthly' | 'open'
  final String eventName;

  // Daily — multiple readings per type
  final List<BpReading> bpReadings;
  final List<VitalReading> pulseReadings;
  final List<VitalReading> sugarReadings;
  final List<VitalReading> cholesterolReadings;
  final List<VitalReading> weightReadings;

  // Units (section-level)
  final String weightUnit;
  final String sugarUnit;
  final String cholesterolUnit;

  // Misc fields — lists to support multiple dates per section
  final List<DateTime> colonoscopyDates;
  final String colonoscopyLocation;
  final String colonoscopyNotes;
  final List<DateTime> periodDates;
  final String periodNotes;
  final List<DateTime> mammogramDates;
  final String mammogramLocation;
  final String mammogramNotes;
  final List<DateTime> dentalDates;
  final String dentalLocation;
  final String dentalNotes;
  final List<DateTime> eyeExamDates;
  final String eyeExamLocation;
  final String eyeExamNotes;
  final List<DateTime> eventDates;

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
    this.pulseReadings = const [],
    this.sugarReadings = const [],
    this.cholesterolReadings = const [],
    this.weightReadings = const [],
    this.weightUnit = 'lbs',
    this.sugarUnit = 'mg/dL',
    this.cholesterolUnit = 'mg/dL',
    this.colonoscopyDates = const [],
    this.colonoscopyLocation = '',
    this.colonoscopyNotes = '',
    this.periodDates = const [],
    this.periodNotes = '',
    this.mammogramDates = const [],
    this.mammogramLocation = '',
    this.mammogramNotes = '',
    this.dentalDates = const [],
    this.dentalLocation = '',
    this.dentalNotes = '',
    this.eyeExamDates = const [],
    this.eyeExamLocation = '',
    this.eyeExamNotes = '',
    this.eventDates = const [],
    required this.riskLevel,
    this.notes = '',
    this.doctorId,
    this.location = '',
  });

  // Single-date computed getters — most recent date in each list
  DateTime? get colonoscopyDate => colonoscopyDates.isNotEmpty ? colonoscopyDates.last : null;
  DateTime? get periodDate => periodDates.isNotEmpty ? periodDates.last : null;
  DateTime? get mammogramDate => mammogramDates.isNotEmpty ? mammogramDates.last : null;
  DateTime? get dentalDate => dentalDates.isNotEmpty ? dentalDates.last : null;
  DateTime? get eyeExamDate => eyeExamDates.isNotEmpty ? eyeExamDates.last : null;

  // Display getters — use latest reading
  bool get hasBP => bpReadings.isNotEmpty;
  String get bpDisplay => hasBP
      ? '${bpReadings.last.systolic}/${bpReadings.last.diastolic} mmHg'
      : '—';

  bool get hasPulse => pulseReadings.isNotEmpty;
  String get pulseDisplay => hasPulse
      ? '${pulseReadings.last.value.toInt()} bpm'
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
        'pulseReadings': pulseReadings.map((r) => r.toJson()).toList(),
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
        'eventDates': eventDates.map((d) => d.toIso8601String()).toList(),
        'riskLevel': riskLevel,
        'notes': notes,
        'doctorId': doctorId,
        if (location.isNotEmpty) 'location': location,
      };

  static DateTime? _tryParse(dynamic value) {
    if (value == null) return null;
    try { return DateTime.parse(value as String).toLocal(); } catch (_) { return null; }
  }

  // Parses a date column that may contain either a single ISO string (old format)
  // or a JSON array of ISO strings (new format for multi-date history).
  static List<DateTime> _parseDateList(
      Map<String, dynamic> json, String singleKey, [String? _unused]) {
    final raw = json[singleKey];
    if (raw == null) return [];
    if (raw is String && raw.isNotEmpty) {
      if (raw.startsWith('[')) {
        try {
          final list = jsonDecode(raw) as List;
          return list.map((e) => _tryParse(e)).whereType<DateTime>().toList();
        } catch (_) {}
      }
      final single = _tryParse(raw);
      return single != null ? [single] : [];
    }
    return [];
  }

  factory Vital.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final recordedAt = _tryParse(json['recordedAt']) ?? DateTime.now();

    // readings_data (full multi-reading persistence) takes priority when present
    Map<String, dynamic>? rd;
    final rdRaw = json['readings_data'];
    if (rdRaw != null) {
      try {
        rd = (rdRaw is String ? jsonDecode(rdRaw) : rdRaw) as Map<String, dynamic>?;
      } catch (_) {}
    }

    // BP readings: readings_data > bpReadings list > legacy single-value columns
    List<BpReading> bpReadings = [];
    final rdBp = rd?['bp'] as List?;
    if (rdBp != null && rdBp.isNotEmpty) {
      bpReadings = rdBp.map((e) => BpReading.fromJson(e as Map<String, dynamic>)).toList();
    } else if (json['bpReadings'] != null) {
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

    // Pulse readings
    List<VitalReading> pulseReadings = [];
    final rdPulse = rd?['pulse'] as List?;
    if (rdPulse != null && rdPulse.isNotEmpty) {
      pulseReadings = rdPulse.map((e) => VitalReading.fromJson(e as Map<String, dynamic>)).toList();
    } else if (json['pulseReadings'] != null) {
      pulseReadings = (json['pulseReadings'] as List)
          .map((e) => VitalReading.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['pulse'] != null) {
      pulseReadings = [
        VitalReading(
          id: '${id}_pulse_0',
          value: (json['pulse'] as num).toDouble(),
          time: recordedAt,
        )
      ];
    }

    // Sugar readings
    List<VitalReading> sugarReadings = [];
    final rdSugar = rd?['sugar'] as List?;
    if (rdSugar != null && rdSugar.isNotEmpty) {
      sugarReadings = rdSugar.map((e) => VitalReading.fromJson(e as Map<String, dynamic>)).toList();
    } else if (json['sugarReadings'] != null) {
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

    // Cholesterol readings
    List<VitalReading> cholesterolReadings = [];
    final rdChol = rd?['cholesterol'] as List?;
    if (rdChol != null && rdChol.isNotEmpty) {
      cholesterolReadings = rdChol.map((e) => VitalReading.fromJson(e as Map<String, dynamic>)).toList();
    } else if (json['cholesterolReadings'] != null) {
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

    // Weight readings
    List<VitalReading> weightReadings = [];
    final rdWeight = rd?['weight'] as List?;
    if (rdWeight != null && rdWeight.isNotEmpty) {
      weightReadings = rdWeight.map((e) => VitalReading.fromJson(e as Map<String, dynamic>)).toList();
    } else if (json['weightReadings'] != null) {
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
      pulseReadings: pulseReadings,
      sugarReadings: sugarReadings,
      cholesterolReadings: cholesterolReadings,
      weightReadings: weightReadings,
      weightUnit: json['weightUnit'] ?? 'lbs',
      sugarUnit: json['sugarUnit'] ?? 'mg/dL',
      cholesterolUnit: json['cholesterolUnit'] ?? 'mg/dL',
      colonoscopyDates: _parseDateList(json, 'colonoscopyDate'),
      colonoscopyLocation: json['colonoscopyLocation'] ?? '',
      colonoscopyNotes: json['colonoscopyNotes'] ?? '',
      periodDates: _parseDateList(json, 'periodDate'),
      periodNotes: json['periodNotes'] ?? '',
      mammogramDates: _parseDateList(json, 'mammogramDate'),
      mammogramLocation: json['mammogramLocation'] ?? '',
      mammogramNotes: json['mammogramNotes'] ?? '',
      dentalDates: _parseDateList(json, 'dentalDate'),
      dentalLocation: json['dentalLocation'] ?? '',
      dentalNotes: json['dentalNotes'] ?? '',
      eyeExamDates: _parseDateList(json, 'eyeExamDate'),
      eyeExamLocation: json['eyeExamLocation'] ?? '',
      eyeExamNotes: json['eyeExamNotes'] ?? '',
      eventDates: _parseDateList(json, 'eventDates'),
      riskLevel: json['riskLevel'] ?? 'Low',
      notes: json['notes'] ?? '',
      doctorId: json['doctorId'] as String?,
      location: json['location'] ?? '',
    );
  }
}
